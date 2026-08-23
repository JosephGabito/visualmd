/// Keeps the last word of a paragraph from standing alone.
///
/// A single word on the last line is a widow: the eye reaches it, finds no
/// line, and the paragraph ends with a stumble. The old remedy is the only
/// one that survives re-flowing text — bind the last two words with a space
/// that cannot break, so the pair falls together or not at all.
abstract final class WidowBinding {
  /// A space that no line may break at.
  static const nonBreakingSpace = '\u00A0';

  /// Short paragraphs are left alone: with three words or fewer the last
  /// line is the only line, and binding would only narrow it.
  static const leastWords = 4;

  /// [text] with the final space bound, when it is worth binding.
  static String bind(String text) {
    if (text.trimRight().length != text.length) return text;
    final words = text.trim().split(RegExp(r'\s+'));
    if (words.length < leastWords) return text;
    return bindLastSpace(text);
  }

  /// Binds the final breakable space without making a second decision about
  /// paragraph length. The caller uses this when the paragraph spans several
  /// styled runs and has already counted the whole sentence.
  static String bindLastSpace(String text) {
    if (text.trimRight().length != text.length) return text;
    final lastSpace = text.lastIndexOf(RegExp(r'[ \t]'));
    if (lastSpace <= 0) return text;
    return '${text.substring(0, lastSpace)}$nonBreakingSpace${text.substring(lastSpace + 1)}';
  }
}
