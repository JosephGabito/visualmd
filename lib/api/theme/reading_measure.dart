import 'package:flutter/widgets.dart';

/// How wide a column has to be to hold a given number of characters, measured
/// from the face actually in use rather than assumed.
///
/// A theme may name any serif; a wide one would otherwise stretch the line
/// past what the eye can track. Asking the font settles it.
abstract final class ReadingMeasure {
  /// Ordinary English prose: the mix of letters and spaces a reader meets,
  /// rather than an alphabet, which over-weights rare wide glyphs.
  static const _sample =
      'The system already completes complex work. The inventory explains why '
      'that work remains correct when a component changes or a worker stops.';

  static final _advances = <TextStyle, double>{};

  /// The style as the text engine will actually shape it. Flutter applies
  /// [TextScaler] when it builds the paragraph; the measuring stick has to do
  /// the same or accessibility text scaling shortens the line behind its back.
  static TextStyle _scaled(TextStyle style, TextScaler scaler) {
    final size = style.fontSize;
    return size == null ? style : style.copyWith(fontSize: scaler.scale(size));
  }

  /// Mean advance per character for [style], in logical pixels.
  static double advance(
    TextStyle style, {
    TextScaler scaler = TextScaler.noScaling,
  }) {
    final shaped = _scaled(style, scaler);
    return _advances.putIfAbsent(shaped, () {
      final painter = TextPainter(
        text: TextSpan(text: _sample, style: shaped),
        textDirection: TextDirection.ltr,
      )..layout();
      return painter.width / _sample.length;
    });
  }

  /// The advance of one run of text in [style] — used for hanging a mark by
  /// its own width rather than by a guess.
  static double widthOf(
    String text,
    TextStyle style, {
    TextScaler scaler = TextScaler.noScaling,
  }) {
    final shaped = _scaled(style, scaler);
    final painter = TextPainter(
      text: TextSpan(text: text, style: shaped),
      textDirection: TextDirection.ltr,
    )..layout();
    return painter.width;
  }

  /// The column width that holds [characters] of [style].
  static double columnWidth(
    TextStyle style,
    double characters, {
    TextScaler scaler = TextScaler.noScaling,
  }) => advance(style, scaler: scaler) * characters;
}
