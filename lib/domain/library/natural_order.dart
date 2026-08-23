/// Orders names the way a human shelves them: case-insensitive, and with
/// embedded numbers compared by value (`2-setup` before `10-deploy`).
abstract final class NaturalOrder {
  static final _chunk = RegExp(r'(\d+|\D+)');

  static int compare(String a, String b) {
    final aChunks = _chunk
        .allMatches(a.toLowerCase())
        .map((m) => m[0]!)
        .toList();
    final bChunks = _chunk
        .allMatches(b.toLowerCase())
        .map((m) => m[0]!)
        .toList();
    final n = aChunks.length < bChunks.length ? aChunks.length : bChunks.length;
    for (var i = 0; i < n; i++) {
      final x = aChunks[i], y = bChunks[i];
      final xn = int.tryParse(x), yn = int.tryParse(y);
      final c = (xn != null && yn != null) ? xn.compareTo(yn) : x.compareTo(y);
      if (c != 0) return c;
    }
    return aChunks.length.compareTo(bChunks.length);
  }
}
