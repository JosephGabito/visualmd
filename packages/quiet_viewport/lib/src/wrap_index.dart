/// Resolves the source offset at which each visual line begins.
///
/// The first offset must be zero. A trailing offset equal to the input length
/// represents the empty line after a final hard break.
typedef VisualLineStarts = List<int> Function(String text);

/// One visual line's half-open source range.
final class VisualLineRange {
  final int start;
  final int end;

  const VisualLineRange(this.start, this.end);
}

/// An append-only index from soft-wrapped lines to source offsets.
///
/// Line breaking itself belongs to the host text engine and enters through
/// [resolve]. This class owns only the persistent geometry: it feeds bounded
/// source windows to that engine, commits every complete line, and retains the
/// final unfinished line as the only overlap for a later append.
///
/// [append] trusts an upstream revision contract instead of rescanning the
/// retained prefix. Its work is therefore proportional to the new suffix plus
/// the one visual line which the suffix is still allowed to extend.
final class AppendWrapIndex {
  final VisualLineStarts resolve;
  final int windowCodeUnits;

  final List<int> _starts = [0];
  String _source = '';
  int _indexedLength = 0;
  int _lastIndexedCodeUnits = 0;
  int _largestWindowCodeUnits = 0;

  AppendWrapIndex({
    required String source,
    required this.resolve,
    this.windowCodeUnits = 4096,
  }) {
    if (windowCodeUnits < 2) {
      throw RangeError.value(
        windowCodeUnits,
        'windowCodeUnits',
        'Must leave room to avoid splitting a surrogate pair',
      );
    }
    replace(source);
  }

  int get length => _starts.length;
  int get sourceLength => _source.length;

  /// Code units passed to [resolve] by the most recent operation.
  ///
  /// This includes the bounded overlap needed to settle the previous final
  /// line, so it is deliberately a work measure rather than a suffix length.
  int get lastIndexedCodeUnits => _lastIndexedCodeUnits;

  /// Largest single source window passed to [resolve].
  int get largestWindowCodeUnits => _largestWindowCodeUnits;

  void replace(String source) {
    _source = source;
    _starts
      ..clear()
      ..add(0);
    _indexedLength = 0;
    _indexToEnd();
  }

  /// Indexes a source revision whose prefix is already represented here.
  ///
  /// [baseLength] is the upstream proof that [source] directly extends the
  /// indexed revision. Comparing the complete strings here would make every
  /// append scan the prefix this structure exists to retain.
  void append({required int baseLength, required String source}) {
    if (baseLength != _source.length) {
      throw StateError(
        'Append base $baseLength does not match retained length '
        '${_source.length}.',
      );
    }
    if (source.length < baseLength) {
      throw StateError(
        'Append source length ${source.length} precedes base $baseLength.',
      );
    }
    _source = source;
    _indexedLength = baseLength;
    _indexToEnd();
  }

  VisualLineRange rangeAt(int index) {
    RangeError.checkValidIndex(index, this, 'index', length);
    return VisualLineRange(
      _starts[index],
      index + 1 < _starts.length ? _starts[index + 1] : _source.length,
    );
  }

  int startAt(int index) {
    RangeError.checkValidIndex(index, this, 'index', length);
    return _starts[index];
  }

  void _indexToEnd() {
    _lastIndexedCodeUnits = 0;
    _largestWindowCodeUnits = 0;
    var measuredEnd = _indexedLength;
    while (measuredEnd < _source.length) {
      final requestedEnd = (measuredEnd + windowCodeUnits).clamp(
        0,
        _source.length,
      );
      final end = _surrogateSafeEnd(requestedEnd);
      final tailStart = _starts.last;
      final window = _source.substring(tailStart, end);
      _lastIndexedCodeUnits += window.length;
      if (window.length > _largestWindowCodeUnits) {
        _largestWindowCodeUnits = window.length;
      }

      final localStarts = resolve(window);
      _validateStarts(localStarts, window.length);
      for (final local in localStarts.skip(1)) {
        final absolute = tailStart + local;
        if (absolute > _starts.last) _starts.add(absolute);
      }
      measuredEnd = end;
    }
    _indexedLength = _source.length;
  }

  int _surrogateSafeEnd(int requested) {
    if (requested <= 0 || requested >= _source.length) return requested;
    final before = _source.codeUnitAt(requested - 1);
    final after = _source.codeUnitAt(requested);
    final splitsPair =
        before >= 0xD800 &&
        before <= 0xDBFF &&
        after >= 0xDC00 &&
        after <= 0xDFFF;
    return splitsPair ? requested - 1 : requested;
  }

  static void _validateStarts(List<int> starts, int length) {
    if (starts.isEmpty || starts.first != 0) {
      throw StateError('A visual line resolver must begin at source offset 0.');
    }
    var previous = -1;
    for (final start in starts) {
      if (start <= previous || start < 0 || start > length) {
        throw StateError(
          'Visual line offsets must increase within 0..$length: $starts',
        );
      }
      previous = start;
    }
  }
}
