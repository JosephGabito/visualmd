import 'dart:collection';

/// An immutable indexed sequence whose replacements share untouched subtrees.
///
/// The AVL rope stores small immutable leaves. Random access and suffix
/// replacement are logarithmic in sequence length; ordered iteration is
/// linear and does not materialize a second list.
final class PersistentSequence<T> extends ListBase<T> {
  final _SequenceTree<T>? _root;

  PersistentSequence._(this._root);

  factory PersistentSequence.from(Iterable<T> values) {
    if (values is PersistentSequence<T>) return values;
    final stored = values.toList(growable: false);
    return PersistentSequence._(_treeFrom(stored));
  }

  @override
  int get length => _root?.length ?? 0;

  @override
  set length(int value) =>
      throw UnsupportedError('Persistent sequences are immutable');

  @override
  T operator [](int index) {
    RangeError.checkValidIndex(index, this);
    return _valueAt(_root!, index);
  }

  @override
  void operator []=(int index, T value) =>
      throw UnsupportedError('Persistent sequences are immutable');

  @override
  Iterator<T> get iterator => _SequenceTreeIterator(_root);

  PersistentSequence<T> replace({
    required int index,
    required int removeCount,
    required Iterable<T> values,
  }) {
    RangeError.checkValueInInterval(index, 0, length, 'index');
    RangeError.checkValueInInterval(
      removeCount,
      0,
      length - index,
      'removeCount',
    );
    final (before, remainder) = _splitTree(_root, index);
    final (_, after) = _splitTree(remainder, removeCount);
    final inserted = _treeFrom(values.toList(growable: false));
    return PersistentSequence._(
      _joinTrees(_joinTrees(before, inserted), after),
    );
  }
}

sealed class _SequenceTree<T> {
  int get length;
  int get height;
}

final class _SequenceLeaf<T> extends _SequenceTree<T> {
  final List<T> values;

  _SequenceLeaf(List<T> values)
    : values = List.unmodifiable(values),
      assert(values.isNotEmpty);

  @override
  int get length => values.length;

  @override
  int get height => 1;
}

final class _SequenceBranch<T> extends _SequenceTree<T> {
  final _SequenceTree<T> left;
  final _SequenceTree<T> right;
  @override
  final int length;
  @override
  final int height;

  _SequenceBranch(this.left, this.right)
    : length = left.length + right.length,
      height = 1 + (left.height > right.height ? left.height : right.height);
}

_SequenceTree<T>? _treeFrom<T>(List<T> values) {
  if (values.isEmpty) return null;
  const leafSize = 32;
  var level = <_SequenceTree<T>>[
    for (var start = 0; start < values.length; start += leafSize)
      _SequenceLeaf(
        values.sublist(
          start,
          start + leafSize < values.length ? start + leafSize : values.length,
        ),
      ),
  ];
  while (level.length > 1) {
    final next = <_SequenceTree<T>>[];
    for (var index = 0; index < level.length; index += 2) {
      next.add(
        index + 1 < level.length
            ? _SequenceBranch(level[index], level[index + 1])
            : level[index],
      );
    }
    level = next;
  }
  return level.single;
}

T _valueAt<T>(_SequenceTree<T> tree, int index) {
  var node = tree;
  var offset = index;
  while (node is _SequenceBranch<T>) {
    if (offset < node.left.length) {
      node = node.left;
    } else {
      offset -= node.left.length;
      node = node.right;
    }
  }
  return (node as _SequenceLeaf<T>).values[offset];
}

(_SequenceTree<T>?, _SequenceTree<T>?) _splitTree<T>(
  _SequenceTree<T>? tree,
  int index,
) {
  if (tree == null) return (null, null);
  if (index == 0) return (null, tree);
  if (index == tree.length) return (tree, null);
  switch (tree) {
    case _SequenceLeaf<T>(:final values):
      return (
        _SequenceLeaf(values.sublist(0, index)),
        _SequenceLeaf(values.sublist(index)),
      );
    case _SequenceBranch<T>(:final left, :final right):
      if (index < left.length) {
        final (before, after) = _splitTree(left, index);
        return (before, _joinTrees(after, right));
      }
      if (index == left.length) return (left, right);
      final (before, after) = _splitTree(right, index - left.length);
      return (_joinTrees(left, before), after);
  }
}

_SequenceTree<T>? _joinTrees<T>(
  _SequenceTree<T>? left,
  _SequenceTree<T>? right,
) {
  if (left == null) return right;
  if (right == null) return left;
  if (left.height > right.height + 1) {
    final branch = left as _SequenceBranch<T>;
    return _balance(
      _SequenceBranch(branch.left, _joinTrees(branch.right, right)!),
    );
  }
  if (right.height > left.height + 1) {
    final branch = right as _SequenceBranch<T>;
    return _balance(
      _SequenceBranch(_joinTrees(left, branch.left)!, branch.right),
    );
  }
  return _SequenceBranch(left, right);
}

_SequenceTree<T> _balance<T>(_SequenceBranch<T> node) {
  final balance = node.left.height - node.right.height;
  if (balance > 1) {
    final left = node.left as _SequenceBranch<T>;
    if (left.right.height > left.left.height) {
      final pivot = left.right as _SequenceBranch<T>;
      return _SequenceBranch(
        _SequenceBranch(left.left, pivot.left),
        _SequenceBranch(pivot.right, node.right),
      );
    }
    return _SequenceBranch(left.left, _SequenceBranch(left.right, node.right));
  }
  if (balance < -1) {
    final right = node.right as _SequenceBranch<T>;
    if (right.left.height > right.right.height) {
      final pivot = right.left as _SequenceBranch<T>;
      return _SequenceBranch(
        _SequenceBranch(node.left, pivot.left),
        _SequenceBranch(pivot.right, right.right),
      );
    }
    return _SequenceBranch(_SequenceBranch(node.left, right.left), right.right);
  }
  return node;
}

final class _SequenceTreeIterator<T> implements Iterator<T> {
  final List<_SequenceTree<T>> _stack = [];
  Iterator<T>? _leaf;
  T? _current;

  _SequenceTreeIterator(_SequenceTree<T>? root) {
    if (root != null) _stack.add(root);
  }

  @override
  T get current => _current as T;

  @override
  bool moveNext() {
    while (true) {
      final leaf = _leaf;
      if (leaf != null && leaf.moveNext()) {
        _current = leaf.current;
        return true;
      }
      _leaf = null;
      if (_stack.isEmpty) {
        _current = null;
        return false;
      }
      final node = _stack.removeLast();
      switch (node) {
        case _SequenceLeaf<T>(:final values):
          _leaf = values.iterator;
        case _SequenceBranch<T>(:final left, :final right):
          _stack
            ..add(right)
            ..add(left);
      }
    }
  }
}
