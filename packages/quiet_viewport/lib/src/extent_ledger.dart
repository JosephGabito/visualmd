/// The geometry known before an item is mounted.
final class ExtentSeed<K extends Object> {
  final K key;
  final int revision;
  final double estimatedExtent;

  const ExtentSeed({
    required this.key,
    required this.revision,
    required this.estimatedExtent,
  });
}

/// A change to the coordinate system caused by better item geometry.
///
/// [scrollOffsetDelta] is the exact compensation which keeps the top of the
/// chosen anchor at the same viewport coordinate. It is zero when the changed
/// item follows the anchor.
final class ExtentCorrection<K extends Object> {
  /// The item whose estimate changed, or null for an empty global relayout.
  final K? key;
  final double contentExtentDelta;
  final double scrollOffsetDelta;

  const ExtentCorrection({
    required this.key,
    required this.contentExtentDelta,
    required this.scrollOffsetDelta,
  });
}

/// An append-optimized geometry index for variable-height viewport items.
///
/// Prefix and total extents are backed by a Fenwick tree. Appending, measuring,
/// and asking for the position of an item are O(log n); looking up identity is
/// O(1). The ledger performs no rendering and has no Flutter dependency.
final class StableExtentLedger<K extends Object> {
  final List<K> _keys = [];
  final List<int> _revisions = [];
  final Map<K, int> _indexes = {};
  final _FenwickTree _extents = _FenwickTree();

  int _layoutRevision;

  StableExtentLedger({int layoutRevision = 0})
    : _layoutRevision = layoutRevision {
    if (layoutRevision < 0) {
      throw RangeError.value(layoutRevision, 'layoutRevision');
    }
  }

  int get length => _keys.length;
  int get layoutRevision => _layoutRevision;
  double get totalExtent => _extents.total;

  Iterable<K> get keys => _keys;

  void append(ExtentSeed<K> seed) {
    _requireExtent(seed.estimatedExtent);
    if (seed.revision < 0) {
      throw RangeError.value(seed.revision, 'revision');
    }
    if (_indexes.containsKey(seed.key)) {
      throw StateError('Duplicate viewport item key: ${seed.key}');
    }
    final index = _keys.length;
    _keys.add(seed.key);
    _revisions.add(seed.revision);
    _indexes[seed.key] = index;
    _extents.append(seed.estimatedExtent);
  }

  void appendAll(Iterable<ExtentSeed<K>> seeds) {
    final incoming = seeds.toList(growable: false);
    final claimed = _indexes.keys.toSet();
    for (final seed in incoming) {
      _requireExtent(seed.estimatedExtent);
      if (seed.revision < 0) {
        throw RangeError.value(seed.revision, 'revision');
      }
      if (!claimed.add(seed.key)) {
        throw StateError('Duplicate viewport item key: ${seed.key}');
      }
    }
    if (_keys.isEmpty) {
      for (var index = 0; index < incoming.length; index++) {
        final seed = incoming[index];
        _keys.add(seed.key);
        _revisions.add(seed.revision);
        _indexes[seed.key] = index;
      }
      _extents.replaceAll([for (final seed in incoming) seed.estimatedExtent]);
      return;
    }
    for (final seed in incoming) {
      append(seed);
    }
  }

  double extentOf(K key) => _extents.valueAt(_indexOf(key));

  int indexOf(K key) => _indexOf(key);

  /// The content coordinate at the leading edge of [key].
  double leadingOffsetOf(K key) => _extents.prefix(_indexOf(key));

  /// The item occupying [offset], found without scanning its prefix.
  ///
  /// At an exact boundary the following item owns the coordinate. Values
  /// outside the content clamp to the first or last item.
  K? keyAtOffset(double offset) {
    if (length == 0) return null;
    if (!offset.isFinite) {
      throw RangeError.value(offset, 'offset', 'Must be finite');
    }
    final bounded = offset.clamp(0.0, totalExtent).toDouble();
    return _keys[_extents.indexAtOffset(bounded).clamp(0, length - 1)];
  }

  /// Replaces `[start, length)` while retaining measured prefix geometry.
  ExtentCorrection<K> replaceTail({
    required int start,
    required Iterable<ExtentSeed<K>> seeds,
    K? anchor,
  }) {
    RangeError.checkValueInInterval(start, 0, length, 'start');
    final incoming = seeds.toList(growable: false);
    final retainedAnchor = anchor != null && _indexes.containsKey(anchor);
    final anchorIndex = retainedAnchor ? _indexes[anchor]! : null;
    final anchorBefore = anchorIndex == null
        ? 0.0
        : _extents.prefix(anchorIndex);
    final totalBefore = totalExtent;

    final incomingKeys = <K>{};
    for (final seed in incoming) {
      _requireExtent(seed.estimatedExtent);
      if (seed.revision < 0) {
        throw RangeError.value(seed.revision, 'revision');
      }
      final existing = _indexes[seed.key];
      if (!incomingKeys.add(seed.key) ||
          (existing != null && existing < start)) {
        throw StateError('Duplicate viewport item key: ${seed.key}');
      }
    }

    for (var index = start; index < _keys.length; index++) {
      _indexes.remove(_keys[index]);
    }
    _keys.removeRange(start, _keys.length);
    _revisions.removeRange(start, _revisions.length);
    _extents.truncate(start);
    for (final seed in incoming) {
      append(seed);
    }

    final anchorAfter = anchor != null && _indexes.containsKey(anchor)
        ? _extents.prefix(_indexes[anchor]!)
        : anchorBefore;
    return ExtentCorrection(
      key: anchor,
      contentExtentDelta: totalExtent - totalBefore,
      scrollOffsetDelta: retainedAnchor ? anchorAfter - anchorBefore : 0,
    );
  }

  /// Records real layout geometry when both the item and layout revisions are
  /// still current. A stale asynchronous result is ignored.
  ExtentCorrection<K>? measure({
    required K key,
    required int itemRevision,
    required int layoutRevision,
    required double extent,
    K? anchor,
  }) {
    _requireExtent(extent);
    final index = _indexes[key];
    if (index == null ||
        _revisions[index] != itemRevision ||
        _layoutRevision != layoutRevision) {
      return null;
    }
    return _changeExtent(index, key, extent, anchor);
  }

  /// Invalidates measured geometry for one revised item and installs its next
  /// deterministic estimate. Identity remains stable.
  ExtentCorrection<K> revise({
    required K key,
    required int revision,
    required double estimatedExtent,
    K? anchor,
  }) {
    _requireExtent(estimatedExtent);
    final index = _indexOf(key);
    if (revision <= _revisions[index]) {
      throw StateError(
        'Item $key revision $revision does not follow '
        '${_revisions[index]}.',
      );
    }
    _revisions[index] = revision;
    return _changeExtent(index, key, estimatedExtent, anchor);
  }

  /// Starts a new width/type/theme geometry epoch.
  ///
  /// Estimates must cover the existing sequence exactly. Applying the change
  /// in one operation lets the caller compensate one anchor once rather than
  /// exposing a cascade of intermediate coordinate systems.
  ExtentCorrection<K> relayout({
    required int revision,
    required Iterable<double> estimatedExtents,
    K? anchor,
  }) {
    if (revision <= _layoutRevision) {
      throw StateError(
        'Layout revision $revision does not follow $_layoutRevision.',
      );
    }
    final next = estimatedExtents.toList(growable: false);
    if (next.length != length) {
      throw StateError(
        'Relayout supplied ${next.length} extents for $length items.',
      );
    }
    for (final extent in next) {
      _requireExtent(extent);
    }

    final anchorIndex = anchor == null ? null : _indexOf(anchor);
    final before = anchorIndex == null ? 0.0 : _extents.prefix(anchorIndex);
    final totalBefore = totalExtent;
    _extents.replaceAll(next);
    _layoutRevision = revision;
    final after = anchorIndex == null ? 0.0 : _extents.prefix(anchorIndex);
    return ExtentCorrection(
      key: anchor ?? (_keys.isEmpty ? null : _keys.first),
      contentExtentDelta: totalExtent - totalBefore,
      scrollOffsetDelta: after - before,
    );
  }

  ExtentCorrection<K> _changeExtent(
    int index,
    K key,
    double extent,
    K? anchor,
  ) {
    final previous = _extents.valueAt(index);
    final delta = extent - previous;
    if (delta != 0) _extents.update(index, extent);
    final anchorIndex = anchor == null ? null : _indexOf(anchor);
    return ExtentCorrection(
      key: key,
      contentExtentDelta: delta,
      scrollOffsetDelta: anchorIndex != null && index < anchorIndex ? delta : 0,
    );
  }

  int _indexOf(K key) {
    final index = _indexes[key];
    if (index == null) throw StateError('Unknown viewport item key: $key');
    return index;
  }

  static void _requireExtent(double extent) {
    if (!extent.isFinite || extent < 0) {
      throw RangeError.value(
        extent,
        'extent',
        'Must be finite and nonnegative',
      );
    }
  }
}

/// Geometry for a dense sequence whose stable identity is its integer index.
///
/// Code rows and other immutable indexed media do not need a key map or one
/// revision record per item. This form keeps the same logarithmic prefix,
/// lookup, and measurement operations while constructing a complete estimate
/// vector in O(n).
final class IndexedExtentLedger {
  final _FenwickTree _extents = _FenwickTree();
  int _layoutRevision;

  IndexedExtentLedger(
    Iterable<double> estimatedExtents, {
    int layoutRevision = 0,
  }) : _layoutRevision = layoutRevision {
    if (layoutRevision < 0) {
      throw RangeError.value(layoutRevision, 'layoutRevision');
    }
    final extents = estimatedExtents.toList(growable: false);
    for (final extent in extents) {
      _requireExtent(extent);
    }
    _extents.replaceAll(extents);
  }

  int get length => _extents.length;
  int get layoutRevision => _layoutRevision;
  double get totalExtent => _extents.total;

  double extentAt(int index) {
    RangeError.checkValidIndex(index, this, 'index', length);
    return _extents.valueAt(index);
  }

  double leadingOffsetAt(int index) {
    RangeError.checkValidIndex(index, this, 'index', length);
    return _extents.prefix(index);
  }

  int? indexAtOffset(double offset) {
    if (length == 0) return null;
    if (!offset.isFinite) {
      throw RangeError.value(offset, 'offset', 'Must be finite');
    }
    final bounded = offset.clamp(0.0, totalExtent).toDouble();
    return _extents.indexAtOffset(bounded).clamp(0, length - 1);
  }

  ExtentCorrection<int>? measure({
    required int index,
    required int layoutRevision,
    required double extent,
    int? anchor,
  }) {
    _requireExtent(extent);
    if (layoutRevision != _layoutRevision) return null;
    RangeError.checkValidIndex(index, this, 'index', length);
    if (anchor != null) {
      RangeError.checkValidIndex(anchor, this, 'anchor', length);
    }
    final previous = _extents.valueAt(index);
    final delta = extent - previous;
    if (delta != 0) _extents.update(index, extent);
    return ExtentCorrection(
      key: index,
      contentExtentDelta: delta,
      scrollOffsetDelta: anchor != null && index < anchor ? delta : 0,
    );
  }

  ExtentCorrection<int> relayout({
    required int revision,
    required Iterable<double> estimatedExtents,
    int? anchor,
  }) {
    if (revision <= _layoutRevision) {
      throw StateError(
        'Layout revision $revision does not follow $_layoutRevision.',
      );
    }
    if (anchor != null) {
      RangeError.checkValidIndex(anchor, this, 'anchor', length);
    }
    final next = estimatedExtents.toList(growable: false);
    if (next.length != length) {
      throw StateError(
        'Relayout supplied ${next.length} extents for $length items.',
      );
    }
    for (final extent in next) {
      _requireExtent(extent);
    }
    final before = anchor == null ? 0.0 : _extents.prefix(anchor);
    final totalBefore = totalExtent;
    _extents.replaceAll(next);
    _layoutRevision = revision;
    final after = anchor == null ? 0.0 : _extents.prefix(anchor);
    return ExtentCorrection(
      key: anchor ?? (length == 0 ? null : 0),
      contentExtentDelta: totalExtent - totalBefore,
      scrollOffsetDelta: after - before,
    );
  }

  static void _requireExtent(double extent) {
    if (!extent.isFinite || extent < 0) {
      throw RangeError.value(
        extent,
        'extent',
        'Must be finite and nonnegative',
      );
    }
  }
}

/// One-indexed Fenwick tree with correct dynamic append semantics.
final class _FenwickTree {
  final List<double> _tree = [0];
  final List<double> _values = [];

  int get length => _values.length;
  double get total => prefix(length);

  double valueAt(int index) => _values[index];

  void append(double value) {
    final oneBased = length + 1;
    final span = oneBased & -oneBased;
    final first = oneBased - span;
    final inherited = prefix(oneBased - 1) - prefix(first);
    _values.add(value);
    _tree.add(inherited + value);
  }

  void update(int index, double value) {
    final delta = value - _values[index];
    if (delta == 0) return;
    _values[index] = value;
    for (
      var cursor = index + 1;
      cursor < _tree.length;
      cursor += cursor & -cursor
    ) {
      _tree[cursor] += delta;
    }
  }

  /// Sum of the first [count] values.
  double prefix(int count) {
    var cursor = count;
    var result = 0.0;
    while (cursor > 0) {
      result += _tree[cursor];
      cursor -= cursor & -cursor;
    }
    return result;
  }

  /// Index whose half-open extent interval contains [offset].
  int indexAtOffset(double offset) {
    var index = 0;
    var accumulated = 0.0;
    var bit = 1;
    while (bit << 1 < _tree.length) {
      bit <<= 1;
    }
    while (bit != 0) {
      final next = index + bit;
      if (next < _tree.length && accumulated + _tree[next] <= offset) {
        index = next;
        accumulated += _tree[next];
      }
      bit >>= 1;
    }
    return index;
  }

  void replaceAll(List<double> values) {
    _tree
      ..clear()
      ..addAll(List.filled(values.length + 1, 0));
    _values
      ..clear()
      ..addAll(values);
    for (var oneBased = 1; oneBased <= values.length; oneBased++) {
      _tree[oneBased] += values[oneBased - 1];
      final parent = oneBased + (oneBased & -oneBased);
      if (parent <= values.length) {
        _tree[parent] += _tree[oneBased];
      }
    }
  }

  void truncate(int length) {
    RangeError.checkValueInInterval(length, 0, _values.length, 'length');
    _values.removeRange(length, _values.length);
    _tree.removeRange(length + 1, _tree.length);
  }
}
