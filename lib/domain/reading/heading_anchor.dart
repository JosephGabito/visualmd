/// The rule for turning a heading into something a link can point at.
///
/// GitHub's shape: lowercased, punctuation dropped, spaces to hyphens, and a
/// numeric suffix when a document repeats itself. Both the outline and the
/// page derive anchors from here, so a link found in one always resolves in
/// the other.
final class HeadingAnchors {
  final _taken = <String>{};

  /// The anchor for [text], unique within this document.
  String take(String text) {
    final base = slug(text);
    var anchor = base;
    var n = 1;
    while (!_taken.add(anchor)) {
      anchor = '$base-${n++}';
    }
    return anchor;
  }

  /// The slug for [text], before any de-duplication.
  static String slug(String text) {
    final base = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s-]', unicode: true), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '-');
    return base.isEmpty ? 'section' : base;
  }
}
