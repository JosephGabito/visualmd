import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/domain/reading/content/block.dart';
import 'package:visualmd/domain/reading/content/document_content.dart';
import 'package:visualmd/domain/reading/content/inline.dart';

void main() {
  DocumentBlock block(int index, {int revision = 0}) => DocumentBlock(
    id: DocumentBlockId('block-$index'),
    revision: revision,
    block: ParagraphBlock([TextRun('Block $index')]),
  );

  test('many appends preserve random access and ordered iteration', () {
    var content = DocumentContent.revisioned(const []);
    for (var index = 0; index < 20_000; index++) {
      content = content.apply(
        DocumentMutation.append(
          baseRevision: content.revision,
          revision: content.revision + 1,
          index: content.entries.length,
          blocks: [block(index, revision: content.revision + 1)],
        ),
      );
    }

    expect(content.entries.length, 20_000);
    expect(content.entries.first.id, const DocumentBlockId('block-0'));
    expect(content.entries[10_000].id, const DocumentBlockId('block-10000'));
    expect(content.entries.last.id, const DocumentBlockId('block-19999'));
    expect(content.entries.take(3).map((entry) => entry.block.text), [
      'Block 0',
      'Block 1',
      'Block 2',
    ]);
  });

  test('tail replacement shares the prefix while preserving uniqueness', () {
    final initial = DocumentContent.revisioned([
      for (var index = 0; index < 1000; index++) block(index),
    ]);
    final prefixIdentity = initial.entries[998];
    final replacement = block(999, revision: 1);

    final revised = initial.apply(
      DocumentMutation(
        baseRevision: 0,
        revision: 1,
        operations: [
          ReplaceBlocks(index: 999, removeCount: 1, blocks: [replacement]),
        ],
      ),
    );

    expect(revised.entries[998], same(prefixIdentity));
    expect(revised.entries.last, same(replacement));
    expect(revised.blocks.last.text, 'Block 999');
  });

  test('duplicate identity is rejected without changing the snapshot', () {
    final content = DocumentContent.revisioned([block(0), block(1)]);

    expect(
      () => content.apply(
        DocumentMutation.append(
          baseRevision: 0,
          revision: 1,
          index: 2,
          blocks: [block(0, revision: 1)],
        ),
      ),
      throwsStateError,
    );
    expect(content.entries.map((entry) => entry.id.value), [
      'block-0',
      'block-1',
    ]);
  });

  test('remove then insert may deliberately reuse the removed identity', () {
    final content = DocumentContent.revisioned([block(0), block(1), block(2)]);
    final replacement = DocumentBlock(
      id: const DocumentBlockId('block-1'),
      revision: 1,
      block: const RuleBlock(),
    );

    final revised = content.apply(
      DocumentMutation(
        baseRevision: 0,
        revision: 1,
        operations: [
          ReplaceBlocks(index: 1, removeCount: 1, blocks: [replacement]),
        ],
      ),
    );

    expect(revised.entries[1], same(replacement));
    expect(revised.blocks[1], isA<RuleBlock>());
  });

  test('revisioned entry and block views cannot be mutated externally', () {
    final content = DocumentContent.revisioned([block(0)]);

    expect(() => content.entries.add(block(1)), throwsUnsupportedError);
    expect(
      () => content.blocks.add(const ParagraphBlock([])),
      throwsUnsupportedError,
    );
  });
}
