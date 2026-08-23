/// One entry in a document's table of contents.
final class Heading {
  /// 1 (h1) … 6 (h6).
  final int level;

  /// Plain text, inline markdown stripped.
  final String text;

  /// GitHub-style slug, unique within the document.
  final String anchor;

  /// Zero-based line where the heading starts in the source.
  final int line;

  const Heading({
    required this.level,
    required this.text,
    required this.anchor,
    required this.line,
  });

  @override
  String toString() => 'Heading(h$level "$text" #$anchor @$line)';
}
