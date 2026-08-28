/// Resolves the source offset at which each visual line begins.
///
/// The first offset must be zero. A trailing offset equal to the input length
/// represents the empty line after a final hard break.
typedef VisualLineStarts = List<int> Function(String text);

/// Resolves local visual-line starts with the window's absolute source start.
typedef VisualLineStartsAt = List<int> Function(String text, int sourceOffset);

/// One visual line's half-open source range.
final class VisualLineRange {
  final int start;
  final int end;

  const VisualLineRange(this.start, this.end);
}

/// An append-only index from soft-wrapped lines to source offsets.
///
/// Line breaking itself belongs to the host text engine and enters through
/// a resolver callback. This class owns only the persistent geometry: it feeds bounded
/// source windows to that engine, commits every complete line, and retains the
/// final unfinished line as the only overlap for a later append.
///
/// [append] trusts an upstream revision contract instead of rescanning the
/// retained prefix. Its work is therefore proportional to the new suffix plus
/// the one visual line which the suffix is still allowed to extend.
final class AppendWrapIndex {
  final VisualLineStartsAt resolveAt;
  final int windowCodeUnits;

  final List<int> _starts = [0];
  String _source = '';
  int _indexedLength = 0;
  int _lastIndexedCodeUnits = 0;
  int _largestWindowCodeUnits = 0;

  AppendWrapIndex({
    required String source,
    required VisualLineStarts resolve,
    this.windowCodeUnits = 4096,
  }) : resolveAt = ((text, _) => resolve(text)) {
    _validateWindowSize();
    replace(source);
  }

  /// Creates an eager index whose resolver needs absolute source context.
  AppendWrapIndex.withContext({
    required String source,
    required this.resolveAt,
    this.windowCodeUnits = 4096,
  }) {
    _validateWindowSize();
    replace(source);
  }

  /// Creates an empty index which advances only when [indexNext] is called.
  ///
  /// Partial line starts are deliberately not complete document geometry.
  /// A host can therefore distribute text layout across frame budgets, then
  /// publish the index atomically once [isComplete] becomes true.
  AppendWrapIndex.progressive({
    required String source,
    required VisualLineStarts resolve,
    this.windowCodeUnits = 4096,
  }) : resolveAt = ((text, _) => resolve(text)) {
    _validateWindowSize();
    _source = source;
  }

  /// Creates a progressive index whose resolver needs absolute context.
  AppendWrapIndex.progressiveWithContext({
    required String source,
    required this.resolveAt,
    this.windowCodeUnits = 4096,
  }) {
    _validateWindowSize();
    _source = source;
  }

  int get length => _starts.length;
  int get sourceLength => _source.length;

  /// Whether every visual line in [sourceLength] has been discovered.
  bool get isComplete => _indexedLength == _source.length;

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

  /// Resolves at most [maxWindows] bounded source windows.
  ///
  /// Returns whether the complete index is now ready to publish. Each call is
  /// independent work: [lastIndexedCodeUnits] describes this call only.
  bool indexNext({int maxWindows = 1}) {
    if (maxWindows < 1) {
      throw RangeError.value(maxWindows, 'maxWindows', 'Must be positive');
    }
    _indexWindows(maxWindows);
    return isComplete;
  }

  /// Extends the source without resolving it yet.
  ///
  /// This is the progressive counterpart of [append]. The caller supplies the
  /// same adjacent-revision proof, but a frame scheduler decides when to grant
  /// the new suffix layout time through [indexNext].
  void stageAppend({required int baseLength, required String source}) {
    _validateAppend(baseLength: baseLength, source: source);
    _source = source;
  }

  /// Indexes a source revision whose prefix is already represented here.
  ///
  /// [baseLength] is the upstream proof that [source] directly extends the
  /// indexed revision. Comparing the complete strings here would make every
  /// append scan the prefix this structure exists to retain.
  void append({required int baseLength, required String source}) {
    _validateAppend(baseLength: baseLength, source: source);
    _source = source;
    _indexedLength = baseLength;
    _indexToEnd();
  }

  /// Re-resolves a declared visual-line suffix without visiting its prefix.
  ///
  /// The caller owns the semantic proof that [source] is unchanged before the
  /// start of [line]. This is the layout counterpart of a revisioned tail
  /// mutation: finalized punctuation, a widow binding, or another bounded
  /// projection may change line breaks near the end while every earlier line
  /// remains authoritative.
  void replaceTail({required int line, required String source}) {
    RangeError.checkValidIndex(line, this, 'line', length);
    final start = _starts[line];
    if (source.length < start) {
      throw StateError(
        'Replacement source length ${source.length} precedes line $line at '
        '$start.',
      );
    }
    _source = source;
    _starts.removeRange(line + 1, _starts.length);
    _indexedLength = start;
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

  /// The visual line which owns [offset], found without scanning its prefix.
  int lineAtOffset(int offset) {
    RangeError.checkValueInInterval(offset, 0, _source.length, 'offset');
    var low = 0;
    var high = _starts.length;
    while (low < high) {
      final middle = low + ((high - low) >> 1);
      if (_starts[middle] <= offset) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    return low == 0 ? 0 : low - 1;
  }

  void _indexToEnd() {
    _indexWindows(null);
  }

  void _indexWindows(int? maximum) {
    _lastIndexedCodeUnits = 0;
    _largestWindowCodeUnits = 0;
    var measuredEnd = _indexedLength;
    var windows = 0;
    while (measuredEnd < _source.length &&
        (maximum == null || windows < maximum)) {
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

      final localStarts = resolveAt(window, tailStart);
      _validateStarts(localStarts, window.length);
      for (final local in localStarts.skip(1)) {
        final absolute = tailStart + local;
        if (absolute > _starts.last) _starts.add(absolute);
      }
      measuredEnd = end;
      windows++;
    }
    _indexedLength = measuredEnd;
  }

  void _validateWindowSize() {
    if (windowCodeUnits < 2) {
      throw RangeError.value(
        windowCodeUnits,
        'windowCodeUnits',
        'Must leave room to avoid splitting a surrogate pair',
      );
    }
  }

  void _validateAppend({required int baseLength, required String source}) {
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
