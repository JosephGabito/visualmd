import 'block.dart';

/// Stable identity for one block within a document generation.
///
/// Position and source offset are deliberately not identity: both move when
/// content is inserted before a block. A streaming parser owns these values
/// and preserves them for every block it leaves unchanged.
final class DocumentBlockId {
  final String value;

  const DocumentBlockId(this.value) : assert(value != '');

  @override
  bool operator ==(Object other) =>
      other is DocumentBlockId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

/// Whether later source is still allowed to reinterpret a block.
enum BlockCommitment { committed, provisional }

/// One revisioned block in the reading model.
final class DocumentBlock {
  final DocumentBlockId id;
  final int revision;
  final BlockCommitment commitment;
  final Block block;

  DocumentBlock({
    required this.id,
    required this.revision,
    required this.block,
    this.commitment = BlockCommitment.committed,
  }) {
    if (revision < 0) throw RangeError.value(revision, 'revision');
  }

  DocumentBlock revise({
    required int revision,
    Block? block,
    BlockCommitment? commitment,
  }) {
    if (revision <= this.revision) {
      throw StateError(
        'Block $id revision $revision does not follow ${this.revision}.',
      );
    }
    return DocumentBlock(
      id: id,
      revision: revision,
      block: block ?? this.block,
      commitment: commitment ?? this.commitment,
    );
  }
}

/// One ordered change to a revisioned document.
sealed class BlockMutation {
  const BlockMutation();
}

final class InsertBlocks extends BlockMutation {
  final int index;
  final List<DocumentBlock> blocks;

  InsertBlocks({required this.index, required List<DocumentBlock> blocks})
    : blocks = List.unmodifiable(blocks);
}

final class ReplaceBlocks extends BlockMutation {
  final int index;
  final int removeCount;
  final List<DocumentBlock> blocks;

  ReplaceBlocks({
    required this.index,
    required this.removeCount,
    required List<DocumentBlock> blocks,
  }) : blocks = List.unmodifiable(blocks);
}

final class FinalizeBlocks extends BlockMutation {
  final Set<DocumentBlockId> ids;

  FinalizeBlocks(Set<DocumentBlockId> ids) : ids = Set.unmodifiable(ids);
}

final class RemoveBlocks extends BlockMutation {
  final int index;
  final int count;

  const RemoveBlocks({required this.index, required this.count});
}

/// A lossless transition between two document revisions.
///
/// [baseRevision] makes stale work rejectable without comparing its payload.
/// Operations are applied in order, so each index addresses the sequence left
/// by the operation before it.
final class DocumentMutation {
  final int baseRevision;
  final int revision;
  final List<BlockMutation> operations;

  DocumentMutation({
    required this.baseRevision,
    required this.revision,
    required List<BlockMutation> operations,
  }) : operations = List.unmodifiable(operations) {
    if (baseRevision < 0) {
      throw RangeError.value(baseRevision, 'baseRevision');
    }
    if (revision <= baseRevision) {
      throw StateError(
        'Document revision $revision must follow base revision $baseRevision.',
      );
    }
  }

  factory DocumentMutation.append({
    required int baseRevision,
    required int revision,
    required int index,
    required List<DocumentBlock> blocks,
  }) => DocumentMutation(
    baseRevision: baseRevision,
    revision: revision,
    operations: [InsertBlocks(index: index, blocks: blocks)],
  );
}

/// A document as the reader will meet it: an ordered, revisioned block list.
final class DocumentContent {
  final List<DocumentBlock>? _revisionedEntries;

  /// Stable records for mutation-aware consumers.
  ///
  /// Complete one-shot parsers may still use the const block-only constructor;
  /// their snapshot identities are derived when a revision-aware consumer
  /// first crosses this boundary.
  List<DocumentBlock> get entries =>
      _revisionedEntries ??
      List.unmodifiable([
        for (var index = 0; index < blocks.length; index++)
          DocumentBlock(
            id: DocumentBlockId('snapshot:$index'),
            revision: 0,
            block: blocks[index],
          ),
      ]);

  /// The compatibility view for consumers that do not care about identity.
  final List<Block> blocks;

  final int revision;

  /// The transition which produced this snapshot, when it has a direct
  /// predecessor. Consumers may apply it incrementally only when its base
  /// revision matches the snapshot they already hold.
  final DocumentMutation? mutation;

  const DocumentContent(this.blocks)
    : _revisionedEntries = null,
      revision = 0,
      mutation = null;

  DocumentContent.revisioned(
    List<DocumentBlock> entries, {
    this.revision = 0,
    this.mutation,
  }) : _revisionedEntries = List.unmodifiable(entries),
       blocks = List.unmodifiable(entries.map((entry) => entry.block)) {
    if (revision < 0) throw RangeError.value(revision, 'revision');
    if (mutation != null && mutation!.revision != revision) {
      throw StateError(
        'Mutation revision ${mutation!.revision} does not produce $revision.',
      );
    }
    _requireUniqueIds(_revisionedEntries!);
  }

  static const empty = DocumentContent([]);

  bool get isEmpty => blocks.isEmpty;

  /// Applies a parser-owned mutation and returns the next immutable snapshot.
  ///
  /// This establishes the identity and delta contract. An append-efficient
  /// source and block store are separate layers; consumers can already avoid
  /// revisiting the committed prefix by applying [mutation] directly.
  DocumentContent apply(DocumentMutation next) {
    if (next.baseRevision != revision) {
      throw StateError(
        'Document mutation starts at revision ${next.baseRevision}; '
        'current revision is $revision.',
      );
    }

    final changed = entries.toList();
    for (final operation in next.operations) {
      switch (operation) {
        case InsertBlocks(:final index, :final blocks):
          _requireRange(index, 0, changed.length, 'insert index');
          changed.insertAll(index, blocks);
        case ReplaceBlocks(:final index, :final removeCount, :final blocks):
          _requireCountedRange(index, removeCount, changed.length, 'replace');
          changed.replaceRange(index, index + removeCount, blocks);
        case FinalizeBlocks(:final ids):
          final remaining = ids.toSet();
          for (var index = 0; index < changed.length; index++) {
            final entry = changed[index];
            if (!remaining.remove(entry.id)) continue;
            changed[index] = entry.revise(
              revision: next.revision,
              commitment: BlockCommitment.committed,
            );
          }
          if (remaining.isNotEmpty) {
            throw StateError('Cannot finalize unknown block IDs: $remaining');
          }
        case RemoveBlocks(:final index, :final count):
          _requireCountedRange(index, count, changed.length, 'remove');
          changed.removeRange(index, index + count);
      }
    }
    _requireUniqueIds(changed);
    return DocumentContent.revisioned(
      changed,
      revision: next.revision,
      mutation: next,
    );
  }

  /// The appended records when [previous] is this snapshot's direct prefix.
  /// Returns null when the transition could have changed existing geometry.
  List<DocumentBlock>? appendedSince(DocumentContent previous) {
    final change = mutation;
    if (change == null || change.baseRevision != previous.revision) return null;
    if (change.operations case [InsertBlocks(:final index, :final blocks)]
        when index == previous.entries.length) {
      return blocks;
    }
    return null;
  }

  /// Every heading in order, for matching the outline to the page.
  Iterable<HeadingBlock> get headings => blocks.whereType<HeadingBlock>();

  /// Every word in the document, without decoration.
  String get text => readingTextOfBlocks(blocks, '\n\n');
}

void _requireUniqueIds(Iterable<DocumentBlock> entries) {
  final ids = <DocumentBlockId>{};
  for (final entry in entries) {
    if (!ids.add(entry.id)) {
      throw StateError('Duplicate document block ID: ${entry.id}');
    }
  }
}

void _requireRange(int value, int minimum, int maximum, String name) {
  if (value < minimum || value > maximum) {
    throw RangeError.range(value, minimum, maximum, name);
  }
}

void _requireCountedRange(int index, int count, int length, String name) {
  if (count < 0) throw RangeError.value(count, '$name count');
  _requireRange(index, 0, length, '$name index');
  if (index + count > length) {
    throw RangeError.range(index + count, index, length, '$name end');
  }
}
