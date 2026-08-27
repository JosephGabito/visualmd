/// Append-efficient storage for source which is still arriving.
///
/// Chunks remain exactly as accepted. Appending therefore never copies the
/// committed prefix. Consumers materialize only the source range they need;
/// the full document is available as an explicit, correspondingly expensive
/// operation for compatibility and final verification.
final class ChunkedDocumentSource {
  final List<String> _chunks = [];
  final List<int> _starts = [];
  int _length = 0;

  int get length => _length;

  int get chunkCount => _chunks.length;

  bool get isEmpty => _length == 0;

  /// Adds [source] without joining it to any previously accepted text.
  void append(String source) {
    if (source.isEmpty) return;
    _starts.add(_length);
    _chunks.add(source);
    _length += source.length;
  }

  /// Materializes `[start, end)` and visits no chunk outside that range.
  String range(int start, [int? end]) {
    final limit = end ?? _length;
    RangeError.checkValidRange(start, limit, _length);
    if (start == limit) return '';

    var index = _chunkAt(start);
    final firstStart = _starts[index];
    final first = _chunks[index];
    final firstEnd = firstStart + first.length;
    if (limit <= firstEnd) {
      return first.substring(start - firstStart, limit - firstStart);
    }

    final out = StringBuffer(first.substring(start - firstStart));
    index++;
    while (index < _chunks.length) {
      final chunkStart = _starts[index];
      if (chunkStart >= limit) break;
      final chunk = _chunks[index];
      final take = limit - chunkStart;
      out.write(take < chunk.length ? chunk.substring(0, take) : chunk);
      index++;
    }
    return out.toString();
  }

  String tailFrom(int start) => range(start);

  /// Materializes the complete source. Streaming hot paths should use [range].
  String materialize() => range(0);

  int _chunkAt(int offset) {
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
    return low - 1;
  }
}
