import 'dart:ui' show Color;

import 'theme_format_exception.dart';

/// The semantic colours every widget reads. Nothing is named after a widget;
/// a theme author decides what paper, ink and accent mean, once.
final class ThemePalette {
  /// WCAG's minimum contrast for ordinary-sized text.
  static const minimumTextContrast = 4.5;

  /// The page.
  final Color paper;

  /// Side panels and table heads: a shade off the paper.
  final Color panel;

  /// Hairlines between panes, around code and tables.
  final Color border;

  /// Body text.
  final Color ink;

  /// Secondary text: breadcrumbs, counts, inactive outline entries.
  final Color muted;

  /// Links, the active outline entry, list bullets, the selected shelf row.
  final Color accent;

  /// Header ground of fenced code blocks; the renderer derives the body tone.
  final Color codeBackground;

  /// Soft wash of the accent for selected and hovered rows.
  /// Derived from [accent] over [paper] when a theme does not set it.
  final Color accentSoft;

  /// Text selection highlight. Derived from [accent] when not set.
  final Color selection;

  const ThemePalette({
    required this.paper,
    required this.panel,
    required this.border,
    required this.ink,
    required this.muted,
    required this.accent,
    required this.codeBackground,
    required this.accentSoft,
    required this.selection,
  });

  static const required = [
    'paper',
    'panel',
    'border',
    'ink',
    'muted',
    'accent',
    'codeBackground',
  ];

  factory ThemePalette.fromJson(Map<String, Object?> json) {
    Color colour(String key) {
      final value = json[key];
      if (value is! String) {
        throw ThemeFormatException('palette."$key" is required');
      }
      return parseHexColor(value) ??
          (throw ThemeFormatException(
            'palette."$key" is not a hex colour: "$value"',
          ));
    }

    for (final key in required) {
      if (json[key] == null) {
        throw ThemeFormatException('palette."$key" is required');
      }
    }
    final paper = colour('paper');
    final accent = colour('accent');
    return ThemePalette(
      paper: paper,
      panel: colour('panel'),
      border: colour('border'),
      ink: colour('ink'),
      muted: colour('muted'),
      accent: accent,
      codeBackground: colour('codeBackground'),
      accentSoft: json['accentSoft'] == null
          ? deriveAccentSoft(accent, paper)
          : colour('accentSoft'),
      selection: json['selection'] == null
          ? deriveSelection(accent)
          : colour('selection'),
    );
  }

  Map<String, Object?> toJson() => {
    'paper': hex(paper),
    'panel': hex(panel),
    'border': hex(border),
    'ink': hex(ink),
    'muted': hex(muted),
    'accent': hex(accent),
    'codeBackground': hex(codeBackground),
    'accentSoft': hex(accentSoft),
    'selection': hex(selection),
  };

  /// A 20% wash of the accent over the paper: enough to read as "selected",
  /// not enough to fight the text.
  static Color deriveAccentSoft(Color accent, Color paper) =>
      Color.alphaBlend(accent.withValues(alpha: 0.2), paper);

  static Color deriveSelection(Color accent) => accent.withValues(alpha: 0.3);

  /// Relative luminance contrast, as defined by WCAG for two opaque colours.
  /// A semantic palette can be beautiful in isolation and still fail once a
  /// small label is placed on its actual surface; this measures the pair.
  static double contrastRatio(Color foreground, Color background) {
    final a = foreground.computeLuminance();
    final b = background.computeLuminance();
    final lighter = a > b ? a : b;
    final darker = a > b ? b : a;
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// Accepts `#rgb`, `#rrggbb`, `#rrggbbaa` (and the same without `#`).
  static Color? parseHexColor(String text) {
    var s = text.trim();
    if (s.startsWith('#')) s = s.substring(1);
    if (s.length == 3) s = s.split('').map((c) => '$c$c').join();
    if (s.length == 6) s = '${s}ff';
    if (s.length != 8) return null;
    final value = int.tryParse(s, radix: 16);
    if (value == null) return null;
    final rgb = value >> 8, alpha = value & 0xff;
    return Color((alpha << 24) | rgb);
  }

  static String hex(Color c) {
    final v = c.toARGB32();
    final rgb = (v & 0xffffff).toRadixString(16).padLeft(6, '0');
    final alpha = (v >> 24) & 0xff;
    return alpha == 0xff
        ? '#$rgb'
        : '#$rgb${alpha.toRadixString(16).padLeft(2, '0')}';
  }
}
