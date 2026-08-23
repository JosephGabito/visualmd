/// Turns a writer's keyboard punctuation into a typographer's.
///
/// Straight quotes are hatch marks — they mean inches and feet. A reader
/// never notices proper quotes, dashes and ellipses; they notice their
/// absence, as a faint cheapness in the page.
///
/// This is presentation, not domain: the document's text is unchanged, only
/// the shapes it is set in.
abstract final class TypographicPunctuation {
  static const leftDouble = '“'; // “
  static const rightDouble = '”'; // ”
  static const leftSingle = '‘'; // ‘
  static const rightSingle = '’'; // ’ (also the apostrophe)
  static const enDash = '–'; // –
  static const emDash = '—'; // —
  static const ellipsis = '…'; // …

  /// True when a quote at this position opens rather than closes.
  ///
  /// A quote opens when nothing precedes it, or what precedes it is a space
  /// or an opening bracket — otherwise it closes, which also makes every
  /// apostrophe inside a word a right single quote, as it should be.
  static bool opensAfter(String? previous) {
    if (previous == null || previous.isEmpty) return true;
    return _openers.contains(previous);
  }

  static const _openers = {
    ' ',
    '\t',
    '\n',
    '(',
    '[',
    '{',
    '<',
    '—',
    '–',
    '“',
    '‘',
    '/',
  };

  /// The mark to set for a straight quote, given what came before it.
  static String quote(String straight, String? previous) {
    final opens = opensAfter(previous);
    return switch (straight) {
      '"' => opens ? leftDouble : rightDouble,
      _ => opens ? leftSingle : rightSingle,
    };
  }

  /// The mark to set for a run of hyphens: two make an en dash, three an em.
  static String dash(String hyphens) => hyphens.length >= 3 ? emDash : enDash;
}
