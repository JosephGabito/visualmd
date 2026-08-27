import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/domain/reading/content/block.dart';
import 'package:visualmd/domain/reading/content/document_content.dart';
import 'package:visualmd/domain/reading/content/inline.dart';

DocumentBlock block(
  String id,
  String text, {
  int revision = 0,
  BlockCommitment commitment = BlockCommitment.committed,
}) => DocumentBlock(
  id: DocumentBlockId(id),
  revision: revision,
  commitment: commitment,
  block: ParagraphBlock([TextRun(text)]),
);

void main() {
  test('an append preserves every committed block identity', () {
    final original = DocumentContent.revisioned([
      block('a', 'A'),
      block('b', 'B'),
    ]);
    final tail = block(
      'c',
      'C',
      revision: 1,
      commitment: BlockCommitment.provisional,
    );

    final next = original.apply(
      DocumentMutation.append(
        baseRevision: 0,
        revision: 1,
        index: original.entries.length,
        blocks: [tail],
      ),
    );

    expect(identical(next.entries[0], original.entries[0]), isTrue);
    expect(identical(next.entries[1], original.entries[1]), isTrue);
    expect(next.appendedSince(original), [same(tail)]);
    expect(next.blocks.map((item) => item.text), ['A', 'B', 'C']);
  });

  test('a stale mutation is rejected before its payload is inspected', () {
    final current = DocumentContent.revisioned([
      block('a', 'A', revision: 4),
    ], revision: 4);

    expect(
      () => current.apply(
        DocumentMutation.append(
          baseRevision: 3,
          revision: 5,
          index: 1,
          blocks: [block('late', 'Late', revision: 5)],
        ),
      ),
      throwsStateError,
    );
  });

  test('finalization changes revision without replacing block identity', () {
    final provisional = DocumentContent.revisioned([
      block('tail', 'unfinished', commitment: BlockCommitment.provisional),
    ]);

    final finalized = provisional.apply(
      DocumentMutation(
        baseRevision: 0,
        revision: 1,
        operations: [
          FinalizeBlocks({const DocumentBlockId('tail')}),
        ],
      ),
    );

    expect(finalized.entries.single.id, provisional.entries.single.id);
    expect(finalized.entries.single.revision, 1);
    expect(finalized.entries.single.commitment, BlockCommitment.committed);
  });

  test('duplicate identities cannot enter a document snapshot', () {
    expect(
      () =>
          DocumentContent.revisioned([block('same', 'A'), block('same', 'B')]),
      throwsStateError,
    );
  });

  test('only a direct tail insertion is advertised as an append', () {
    final original = DocumentContent.revisioned([
      block('a', 'A'),
      block('b', 'B'),
    ]);
    final inserted = original.apply(
      DocumentMutation(
        baseRevision: 0,
        revision: 1,
        operations: [
          InsertBlocks(index: 1, blocks: [block('x', 'X')]),
        ],
      ),
    );

    expect(inserted.appendedSince(original), isNull);
  });

  test('a direct suffix replacement exposes only its changed tail', () {
    final original = DocumentContent.revisioned([
      block('a', 'A'),
      block('provisional', 'unfinished'),
    ]);
    final replacement = block('final', 'finished', revision: 1);
    final next = original.apply(
      DocumentMutation(
        baseRevision: 0,
        revision: 1,
        operations: [
          ReplaceBlocks(index: 1, removeCount: 1, blocks: [replacement]),
        ],
      ),
    );

    final change = next.tailChangeSince(original)!;
    expect(change.index, 1);
    expect(change.removeCount, 1);
    expect(change.blocks, [same(replacement)]);
    expect(next.appendedSince(original), isNull);
  });

  test('a direct suffix removal exposes an empty replacement', () {
    final original = DocumentContent.revisioned([
      block('a', 'A'),
      block('provisional', 'unfinished'),
    ]);
    final next = original.apply(
      DocumentMutation(
        baseRevision: 0,
        revision: 1,
        operations: [const RemoveBlocks(index: 1, count: 1)],
      ),
    );

    final change = next.tailChangeSince(original)!;
    expect(change.index, 1);
    expect(change.removeCount, 1);
    expect(change.blocks, isEmpty);
  });

  test('a non-tail replacement is not advertised as bounded suffix work', () {
    final original = DocumentContent.revisioned([
      block('a', 'A'),
      block('b', 'B'),
    ]);
    final next = original.apply(
      DocumentMutation(
        baseRevision: 0,
        revision: 1,
        operations: [
          ReplaceBlocks(
            index: 0,
            removeCount: 1,
            blocks: [block('x', 'X', revision: 1)],
          ),
        ],
      ),
    );

    expect(next.tailChangeSince(original), isNull);
  });

  test('a mutation owns immutable operation and block payloads', () {
    final original = DocumentContent.revisioned([block('a', 'A')]);
    final inserted = <DocumentBlock>[block('b', 'B')];
    final operations = <BlockMutation>[
      InsertBlocks(index: 1, blocks: inserted),
    ];
    final mutation = DocumentMutation(
      baseRevision: 0,
      revision: 1,
      operations: operations,
    );

    inserted.add(block('c', 'C'));
    operations.clear();
    final next = original.apply(mutation);

    expect(next.blocks.map((item) => item.text), ['A', 'B']);
  });

  test('a revision must advance in every runtime mode', () {
    expect(
      () =>
          DocumentMutation(baseRevision: 2, revision: 2, operations: const []),
      throwsStateError,
    );
  });
}
