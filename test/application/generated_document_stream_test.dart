import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/application/generated_document_stream.dart';
import 'package:visualmd/domain/library/document_id.dart';
import 'package:visualmd/domain/library/library_root_id.dart';
import 'package:visualmd/domain/reading/content/document_content.dart';
import 'package:visualmd/infrastructure/markdown/markdown_document_parser.dart';

void main() {
  final documentId = DocumentId(const LibraryRootId('generated'), 'answer.md');
  const streamId = DocumentStreamId('generation-1');

  GeneratedDocumentStreamSession session({
    Duration latency = const Duration(milliseconds: 12),
    int batchCharacters = 4096,
  }) => GeneratedDocumentStreamSession(
    documentId: documentId,
    streamId: streamId,
    parser: const MarkdownDocumentParser(),
    maxLatency: latency,
    maxBatchCharacters: batchCharacters,
  );

  test('tiny deltas coalesce into one bounded-latency parse', () async {
    final generation = session();
    final revision = generation.revisions.first;

    generation
      ..accept(_delta(0, 0, 'A '))
      ..accept(_delta(1, 2, 'streamed '))
      ..accept(_delta(2, 11, 'paragraph'));

    final update = await revision.timeout(const Duration(seconds: 1));
    expect(update.throughSequence, 2);
    expect(update.acceptedSourceLength, 20);
    expect(update.parsedSourceCharacters, 20);
    expect(update.content.blocks.single.text, 'A streamed paragraph');
    expect(update.content.revision, 1);
    await generation.cancel();
  });

  test('a Markdown block boundary flushes without waiting for the timer', () {
    final generation = session(latency: const Duration(seconds: 1));
    final updates = <GeneratedDocumentRevision>[];
    generation.revisions.listen(updates.add);

    generation.accept(_delta(0, 0, 'Readable now.\n\n'));

    expect(updates, hasLength(1));
    expect(updates.single.content.blocks.single.text, 'Readable now.');
    expect(generation.queuedSourceLength, 0);
    return generation.cancel();
  });

  test('the byte budget bounds a batch without dropping source', () {
    final generation = session(
      latency: const Duration(seconds: 1),
      batchCharacters: 8,
    );
    final updates = <GeneratedDocumentRevision>[];
    generation.revisions.listen(updates.add);

    generation
      ..accept(_delta(0, 0, '1234'))
      ..accept(_delta(1, 4, '5678'));

    expect(updates, hasLength(1));
    expect(updates.single.content.text, '12345678');
    expect(updates.single.acceptedSourceLength, 8);
    return generation.cancel();
  });

  test('duplicates are harmless while gaps and offsets are rejected', () async {
    final generation = session(latency: const Duration(seconds: 1));

    expect(generation.accept(_delta(0, 0, 'abc')), isTrue);
    expect(generation.accept(_delta(0, 0, 'abc')), isFalse);
    expect(
      () => generation.accept(_delta(2, 3, 'gap')),
      throwsA(isA<GeneratedDocumentProtocolException>()),
    );
    expect(
      () => generation.accept(_delta(1, 2, 'wrong offset')),
      throwsA(isA<GeneratedDocumentProtocolException>()),
    );
    expect(generation.accept(_delta(1, 3, 'def')), isTrue);
    expect(
      generation.accept(
        const GeneratedDocumentDelta(
          streamId: DocumentStreamId('stale-generation'),
          sequence: 2,
          sourceOffset: 6,
          source: 'ignored',
        ),
      ),
      isFalse,
    );
    expect(generation.acceptedSourceLength, 6);
    await generation.cancel();
  });

  test(
    'finish flushes once, commits canonically, and fences late work',
    () async {
      final generation = session(latency: const Duration(seconds: 1));
      final updates = <GeneratedDocumentRevision>[];
      final done = generation.revisions.listen(updates.add).asFuture<void>();

      generation
        ..accept(_delta(0, 0, '# Answer'))
        ..accept(
          const GeneratedDocumentFinished(
            streamId: streamId,
            sequence: 1,
            sourceLength: 8,
          ),
        );
      await done;

      expect(updates, hasLength(1));
      expect(updates.single.status, GeneratedDocumentStatus.finished);
      expect(updates.single.throughSequence, 1);
      expect(updates.single.content.headings.single.text, 'Answer');
      expect(
        updates.single.content.entries.every(
          (entry) => entry.commitment == BlockCommitment.committed,
        ),
        isTrue,
      );
      expect(generation.accept(_delta(2, 8, ' late')), isFalse);
    },
  );

  test(
    'failure preserves every accepted character and provisional block',
    () async {
      final generation = session(latency: const Duration(seconds: 1));
      final updates = <GeneratedDocumentRevision>[];
      final done = generation.revisions.listen(updates.add).asFuture<void>();

      generation
        ..accept(_delta(0, 0, 'Partial answer'))
        ..accept(
          const GeneratedDocumentFailed(
            streamId: streamId,
            sequence: 1,
            reason: 'producer disconnected',
          ),
        );
      await done;

      expect(updates, hasLength(1));
      expect(updates.single.status, GeneratedDocumentStatus.failed);
      expect(updates.single.failure, 'producer disconnected');
      expect(updates.single.content.text, 'Partial answer');
      expect(updates.single.acceptedSourceLength, 14);
    },
  );

  test(
    'cancel releases queued work and a timer cannot publish it later',
    () async {
      final generation = session(latency: const Duration(milliseconds: 10));
      final updates = <GeneratedDocumentRevision>[];
      generation.revisions.listen(updates.add);
      generation.accept(_delta(0, 0, 'never publish'));

      await generation.cancel();
      await Future<void>.delayed(const Duration(milliseconds: 25));

      expect(updates, isEmpty);
      expect(generation.queuedSourceLength, 0);
      expect(generation.accept(_delta(1, 13, ' late')), isFalse);
    },
  );
}

GeneratedDocumentDelta _delta(int sequence, int offset, String source) =>
    GeneratedDocumentDelta(
      streamId: const DocumentStreamId('generation-1'),
      sequence: sequence,
      sourceOffset: offset,
      source: source,
    );
