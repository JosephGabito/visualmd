/// One physical line's half-open source range, excluding its newline.
final class TextLineRange {
  final int start;
  final int end;

  const TextLineRange(this.start, this.end);
}

/// An append-only index from physical text lines to source offsets.
///
/// Construction visits the initial source once. [append] visits only its
/// suffix, so a streaming renderer never rescans already indexed text.
final class AppendLineIndex {
  final List<int> _starts = [0];
  int _sourceLength = 0;
  int _maximumColumns = 0;
  int _lastLineColumns = 0;
  int _lastIndexedCodeUnits = 0;

  AppendLineIndex([String source = '']) {
    append(source);
  }

  int get length => _starts.length;
  int get sourceLength => _sourceLength;
  int get maximumColumns => _maximumColumns;

  /// Code units visited by the most recent construction or append operation.
  int get lastIndexedCodeUnits => _lastIndexedCodeUnits;

  void append(String suffix) {
    _lastIndexedCodeUnits = suffix.length;
    for (var index = 0; index < suffix.length; index++) {
      if (suffix.codeUnitAt(index) == 10) {
        if (_lastLineColumns > _maximumColumns) {
          _maximumColumns = _lastLineColumns;
        }
        _lastLineColumns = 0;
        _starts.add(_sourceLength + index + 1);
      } else {
        _lastLineColumns++;
      }
    }
    _sourceLength += suffix.length;
    if (_lastLineColumns > _maximumColumns) {
      _maximumColumns = _lastLineColumns;
    }
  }

  TextLineRange rangeAt(int index) {
    RangeError.checkValidIndex(index, this, 'index', length);
    return TextLineRange(
      _starts[index],
      index + 1 < _starts.length ? _starts[index + 1] - 1 : _sourceLength,
    );
  }
}
