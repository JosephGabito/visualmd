import 'dart:collection';

import '../../collection/persistent_sequence.dart';
import 'block.dart';
import 'inline.dart';

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

/// A parser-proven append to the visible text of one stable block.
///
/// Consumers must match [baseRevision] before applying the suffix. The parser
/// owns this fact because recovering it later with `startsWith` would scan the
/// complete accumulated block on every streaming update.
final class BlockTextAppend {
  final int baseRevision;
  final String text;

  const BlockTextAppend({required this.baseRevision, required this.text})
    : assert(baseRevision >= 0);
}

/// A parser-proven append to one stable paragraph's inline structure.
///
/// The suffix begins after the complete prior inline tree, except that a final
/// plain text leaf may continue as a new [TextRun]. Consumers can therefore
/// extend a retained style-range index without comparing the accumulated
/// prefix. Delimiter closure or any other earlier reinterpretation withholds
/// this proof and remains a full block replacement.
final class BlockInlineAppend {
  final int baseRevision;
  final List<Inline> runs;

  BlockInlineAppend({required this.baseRevision, required List<Inline> runs})
    : runs = List.unmodifiable(runs) {
    if (baseRevision < 0) {
      throw RangeError.value(baseRevision, 'baseRevision');
    }
    if (runs.isEmpty) {
      throw ArgumentError.value(runs, 'runs', 'Must contain a visible suffix');
    }
  }
}

/// One revisioned block in the reading model.
final class DocumentBlock {
  final DocumentBlockId id;
  final int revision;
  final BlockCommitment commitment;
  final Block block;
  final BlockTextMetrics textMetrics;
  final BlockTextAppend? textAppend;
  final BlockInlineAppend? inlineAppend;

  DocumentBlock({
    required this.id,
    required this.revision,
    required this.block,
    BlockTextMetrics? textMetrics,
    this.commitment = BlockCommitment.committed,
    this.textAppend,
    this.inlineAppend,
  }) : textMetrics = textMetrics ?? BlockTextMetrics.fromBlock(block) {
    if (revision < 0) throw RangeError.value(revision, 'revision');
    if (textAppend != null && inlineAppend != null) {
      throw StateError('Block $id cannot advertise two append proofs.');
    }
    final appendRevision =
        textAppend?.baseRevision ?? inlineAppend?.baseRevision;
    if (appendRevision != null && appendRevision >= revision) {
      throw StateError(
        'Block $id append starts at revision $appendRevision; '
        'the resulting revision is $revision.',
      );
    }
    assert(() {
      final actual = BlockTextMetrics.fromBlock(block);
      if (actual.codeUnits != this.textMetrics.codeUnits ||
          actual.lineBreaks != this.textMetrics.lineBreaks) {
        throw StateError('Block $id carries stale visible-text metrics.');
      }
      return true;
    }());
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
      textMetrics: block == null ? textMetrics : null,
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

/// One direct suffix transition between adjacent document revisions.
final class DocumentTailChange {
  final int index;
  final int removeCount;
  final List<DocumentBlock> blocks;

  const DocumentTailChange({
    required this.index,
    required this.removeCount,
    required this.blocks,
  });
}

/// A document as the reader will meet it: an ordered, revisioned block list.
final class DocumentContent {
  final List<DocumentBlock>? _revisionedEntries;
  final _PersistentIdSet? _ids;

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
      _ids = null,
      revision = 0,
      mutation = null;

  factory DocumentContent.revisioned(
    List<DocumentBlock> entries, {
    int revision = 0,
    DocumentMutation? mutation,
  }) {
    if (revision < 0) throw RangeError.value(revision, 'revision');
    if (mutation != null && mutation.revision != revision) {
      throw StateError(
        'Mutation revision ${mutation.revision} does not produce $revision.',
      );
    }
    final stored = entries is PersistentSequence<DocumentBlock>
        ? entries
        : PersistentSequence<DocumentBlock>.from(entries);
    return DocumentContent._revisioned(
      stored,
      _PersistentIdSet.from(stored),
      revision: revision,
      mutation: mutation,
    );
  }

  DocumentContent._revisioned(
    PersistentSequence<DocumentBlock> entries,
    this._ids, {
    required this.revision,
    required this.mutation,
  }) : _revisionedEntries = entries,
       blocks = _BlockView(entries);

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

    var changed = _revisionedEntries is PersistentSequence<DocumentBlock>
        ? _revisionedEntries
        : PersistentSequence<DocumentBlock>.from(entries);
    var ids = _ids ?? _PersistentIdSet.from(changed);
    for (final operation in next.operations) {
      switch (operation) {
        case InsertBlocks(:final index, :final blocks):
          _requireRange(index, 0, changed.length, 'insert index');
          (changed, ids) = _replacePersistent(
            changed,
            ids,
            index: index,
            removeCount: 0,
            blocks: blocks,
          );
        case ReplaceBlocks(:final index, :final removeCount, :final blocks):
          _requireCountedRange(index, removeCount, changed.length, 'replace');
          (changed, ids) = _replacePersistent(
            changed,
            ids,
            index: index,
            removeCount: removeCount,
            blocks: blocks,
          );
        case FinalizeBlocks(:final ids):
          final remaining = ids.toSet();
          for (var index = 0; index < changed.length; index++) {
            final entry = changed[index];
            if (!remaining.remove(entry.id)) continue;
            changed = changed.replace(
              index: index,
              removeCount: 1,
              values: [
                entry.revise(
                  revision: next.revision,
                  commitment: BlockCommitment.committed,
                ),
              ],
            );
          }
          if (remaining.isNotEmpty) {
            throw StateError('Cannot finalize unknown block IDs: $remaining');
          }
        case RemoveBlocks(:final index, :final count):
          _requireCountedRange(index, count, changed.length, 'remove');
          (changed, ids) = _replacePersistent(
            changed,
            ids,
            index: index,
            removeCount: count,
            blocks: const [],
          );
      }
    }
    return DocumentContent._revisioned(
      changed,
      ids,
      revision: next.revision,
      mutation: next,
    );
  }

  /// The appended records when [previous] is this snapshot's direct prefix.
  /// Returns null when the transition could have changed existing geometry.
  List<DocumentBlock>? appendedSince(DocumentContent previous) {
    final change = tailChangeSince(previous);
    return change != null &&
            change.index == previous.entries.length &&
            change.removeCount == 0
        ? change.blocks
        : null;
  }

  /// The changed suffix when this snapshot directly follows [previous].
  ///
  /// Consumers which own derived indexes can truncate to [DocumentTailChange.index]
  /// and visit only the replacement rather than rebuilding the committed
  /// prefix. Non-tail edits deliberately return null.
  DocumentTailChange? tailChangeSince(DocumentContent previous) {
    final change = mutation;
    if (change == null || change.baseRevision != previous.revision) return null;
    return switch (change.operations) {
      [InsertBlocks(:final index, :final blocks)]
          when index == previous.entries.length =>
        DocumentTailChange(index: index, removeCount: 0, blocks: blocks),
      [ReplaceBlocks(:final index, :final removeCount, :final blocks)]
          when index + removeCount == previous.entries.length =>
        DocumentTailChange(
          index: index,
          removeCount: removeCount,
          blocks: blocks,
        ),
      [RemoveBlocks(:final index, :final count)]
          when index + count == previous.entries.length =>
        DocumentTailChange(index: index, removeCount: count, blocks: const []),
      _ => null,
    };
  }

  /// Every heading in order, for matching the outline to the page.
  Iterable<HeadingBlock> get headings => blocks.whereType<HeadingBlock>();

  /// Every word in the document, without decoration.
  String get text => readingTextOfBlocks(blocks, '\n\n');
}

(PersistentSequence<DocumentBlock>, _PersistentIdSet) _replacePersistent(
  PersistentSequence<DocumentBlock> entries,
  _PersistentIdSet ids, {
  required int index,
  required int removeCount,
  required List<DocumentBlock> blocks,
}) {
  var nextIds = ids;
  for (var removed = 0; removed < removeCount; removed++) {
    nextIds = nextIds.remove(entries[index + removed].id);
  }
  for (final block in blocks) {
    final inserted = nextIds.add(block.id);
    if (!inserted.added) {
      throw StateError('Duplicate document block ID: ${block.id}');
    }
    nextIds = inserted.set;
  }
  return (
    entries.replace(index: index, removeCount: removeCount, values: blocks),
    nextIds,
  );
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

final class _BlockView extends ListBase<Block> {
  final PersistentSequence<DocumentBlock> _entries;

  _BlockView(this._entries);

  @override
  int get length => _entries.length;

  @override
  set length(int value) =>
      throw UnsupportedError('Document blocks are immutable');

  @override
  Block operator [](int index) => _entries[index].block;

  @override
  void operator []=(int index, Block value) =>
      throw UnsupportedError('Document blocks are immutable');

  @override
  Iterator<Block> get iterator => _BlockIterator(_entries.iterator);
}

final class _BlockIterator implements Iterator<Block> {
  final Iterator<DocumentBlock> _entries;

  _BlockIterator(this._entries);

  @override
  Block get current => _entries.current.block;

  @override
  bool moveNext() => _entries.moveNext();
}

final class _PersistentIdSet {
  final _IdNode? _root;

  const _PersistentIdSet._(this._root);

  factory _PersistentIdSet.from(Iterable<DocumentBlock> entries) {
    final values = <String>{};
    for (final entry in entries) {
      if (!values.add(entry.id.value)) {
        throw StateError('Duplicate document block ID: ${entry.id}');
      }
    }
    final sorted = values.toList()..sort();
    return _PersistentIdSet._(_idTreeFromSorted(sorted, 0, sorted.length));
  }

  ({_PersistentIdSet set, bool added}) add(DocumentBlockId id) {
    final result = _insertId(_root, id.value);
    return (set: _PersistentIdSet._(result.node), added: result.added);
  }

  _PersistentIdSet remove(DocumentBlockId id) =>
      _PersistentIdSet._(_removeId(_root, id.value));
}

final class _IdNode {
  final String key;
  final _IdNode? left;
  final _IdNode? right;
  final int height;

  _IdNode(this.key, this.left, this.right)
    : height = 1 + _maxInt(left?.height ?? 0, right?.height ?? 0);
}

_IdNode? _idTreeFromSorted(List<String> values, int start, int end) {
  if (start >= end) return null;
  final middle = start + ((end - start) >> 1);
  return _IdNode(
    values[middle],
    _idTreeFromSorted(values, start, middle),
    _idTreeFromSorted(values, middle + 1, end),
  );
}

({_IdNode node, bool added}) _insertId(_IdNode? node, String key) {
  if (node == null) return (node: _IdNode(key, null, null), added: true);
  final order = key.compareTo(node.key);
  if (order == 0) return (node: node, added: false);
  if (order < 0) {
    final inserted = _insertId(node.left, key);
    if (!inserted.added) return (node: node, added: false);
    return (
      node: _balanceId(_IdNode(node.key, inserted.node, node.right)),
      added: true,
    );
  }
  final inserted = _insertId(node.right, key);
  if (!inserted.added) return (node: node, added: false);
  return (
    node: _balanceId(_IdNode(node.key, node.left, inserted.node)),
    added: true,
  );
}

_IdNode? _removeId(_IdNode? node, String key) {
  if (node == null) return null;
  final order = key.compareTo(node.key);
  if (order < 0) {
    return _balanceId(_IdNode(node.key, _removeId(node.left, key), node.right));
  }
  if (order > 0) {
    return _balanceId(_IdNode(node.key, node.left, _removeId(node.right, key)));
  }
  if (node.left == null) return node.right;
  if (node.right == null) return node.left;
  var successor = node.right!;
  while (successor.left != null) {
    successor = successor.left!;
  }
  return _balanceId(
    _IdNode(successor.key, node.left, _removeId(node.right, successor.key)),
  );
}

_IdNode _balanceId(_IdNode node) {
  final balance = (node.left?.height ?? 0) - (node.right?.height ?? 0);
  if (balance > 1) {
    var left = node.left!;
    if ((left.right?.height ?? 0) > (left.left?.height ?? 0)) {
      left = _rotateIdLeft(left);
    }
    return _rotateIdRight(_IdNode(node.key, left, node.right));
  }
  if (balance < -1) {
    var right = node.right!;
    if ((right.left?.height ?? 0) > (right.right?.height ?? 0)) {
      right = _rotateIdRight(right);
    }
    return _rotateIdLeft(_IdNode(node.key, node.left, right));
  }
  return node;
}

_IdNode _rotateIdLeft(_IdNode node) {
  final pivot = node.right!;
  return _IdNode(
    pivot.key,
    _IdNode(node.key, node.left, pivot.left),
    pivot.right,
  );
}

_IdNode _rotateIdRight(_IdNode node) {
  final pivot = node.left!;
  return _IdNode(
    pivot.key,
    pivot.left,
    _IdNode(node.key, pivot.right, node.right),
  );
}

int _maxInt(int a, int b) => a > b ? a : b;
