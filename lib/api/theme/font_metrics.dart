/// What the bundled faces actually measure.
///
/// Legibility research is consistent on one point: it is the x-height, not
/// the nominal point size, that decides how large text reads. Two faces set
/// at "18 pixels" can differ by a tenth in the size of their letters, which
/// is the difference between comfortable and tiring over a long document.
///
/// So a size in this reader is a size *of letters*, and the font size needed
/// to produce it is worked out per face.
abstract final class FontMetrics {
  /// x-height as a fraction of the em, read from each font's `OS/2` table.
  static const xHeights = <String, double>{
    'Literata': 0.507,
    'Inter': 0.546,
    'Geist Mono': 0.530,
    // A literary face: small letters, long extenders. It is set larger to
    // read the same, which is the whole point of quoting sizes this way.
    'Alegreya': 0.452,
  };

  /// Cap height and descender depth as fractions of the em, from the same
  /// tables. Together they are the ink a line of ordinary Latin text puts on
  /// the page, which is what the line above has to clear.
  static const capHeights = <String, double>{
    'Literata': 0.700,
    'Inter': 0.728,
    'Geist Mono': 0.710,
    'Alegreya': 0.637,
  };

  static const descenders = <String, double>{
    'Literata': 0.308,
    'Inter': 0.244,
    'Geist Mono': 0.295,
    'Alegreya': 0.345,
  };

  /// The white space wanted between the descenders of one line and the
  /// capitals of the next, as a multiple of the x-height.
  ///
  /// This is the one number here chosen by reading rather than measuring —
  /// and it is the number that reproduces the leading this reader had already
  /// settled on for Literata, which is why it is trusted for the others.
  static const lineGap = 1.26;

  /// The line height for [family], as a multiple of the font size.
  ///
  /// Faces differ in how much of the em they use: Literata's ascenders are
  /// unusually tall, Alegreya's are shorter but its descenders deeper. Left
  /// on one multiplier they would sit at visibly different densities, so the
  /// multiplier is worked out per face to leave the same gap.
  static double leadingFor(String family, double fallback) {
    final cap = capHeights[family];
    final descender = descenders[family];
    final x = xHeights[family];
    if (cap == null || descender == null || x == null) return fallback;
    return cap + descender + lineGap * x;
  }

  /// The ratio a size is quoted against. 0.55 is where most faces drawn for
  /// screens sit, so a size means much what it means elsewhere — and a face
  /// with smaller letters is given the extra size it needs to match.
  static const referenceXHeight = 0.55;

  /// The font size that gives [size]'s worth of letters in [family].
  static double sizeFor(String family, double size) {
    final ratio = xHeights[family];
    if (ratio == null) return size;
    return size * referenceXHeight / ratio;
  }

  /// The quoted letter size produced by [fontSize] in [family].
  ///
  /// This is the inverse of [sizeFor]. It lets a contextual run change by an
  /// absolute logical-pixel step even when its surrounding face and its own
  /// face have different x-heights.
  static double letterSizeFor(String family, double fontSize) {
    final ratio = xHeights[family];
    if (ratio == null) return fontSize;
    return fontSize * ratio / referenceXHeight;
  }
}
