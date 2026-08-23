/// Which marks hang outside the column, and how far.
///
/// A quotation mark is mostly white space. Left in the column it carves a
/// notch out of the left edge, and the first line of the paragraph appears
/// to start further right than every line beneath it. Hanging the mark into
/// the margin puts the *text* back on the edge, which is what the eye reads
/// the edge from.
///
/// The fractions are of the mark's own advance. Quotes hang completely;
/// marks that carry more ink hang less, because what is being aligned is the
/// look of the edge, not the arithmetic.
abstract final class HangingPunctuation {
  static const _fractions = <String, double>{
    // Opening quotes, in the shapes a typographer sets them.
    '“': 1.0,
    '‘': 1.0,
    '«': 1.0,
    '„': 1.0,
    '‚': 1.0,
    // The straight forms, in case a document reaches the page unset.
    '"': 1.0,
    "'": 1.0,
    // A dash opening a line of dialogue carries real weight, so it hangs
    // only as far as it can without the line looking pulled out of place.
    '—': 0.5,
    '–': 0.5,
  };

  /// How much of [character]'s advance hangs outside the column, 0 for a
  /// character that does not hang.
  static double fractionFor(String character) => _fractions[character] ?? 0;

  static bool hangs(String character) => fractionFor(character) > 0;
}
