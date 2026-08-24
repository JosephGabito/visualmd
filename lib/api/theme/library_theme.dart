import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'font_licences.dart';
import 'font_metrics.dart';

import '../../presentation/theme/reader_theme.dart';
import '../../presentation/theme/theme_palette.dart';
import '../../presentation/theme/theme_typefaces.dart';

/// The library's materials as the widget tree reads them. Values come from
/// the active [ReaderTheme]; widgets never see a hex.
@immutable
final class LibraryPalette extends ThemeExtension<LibraryPalette> {
  final Color paper;
  final Color panel;
  final Color border;
  final Color ink;
  final Color muted;
  final Color accent;
  final Color accentSoft;

  /// Header ground for fenced code; `ReadingTheme` derives the body tone.
  final Color codeBackground;
  final Color selection;

  const LibraryPalette({
    required this.paper,
    required this.panel,
    required this.border,
    required this.ink,
    required this.muted,
    required this.accent,
    required this.accentSoft,
    required this.codeBackground,
    required this.selection,
  });

  /// The tokens of a theme, as the widget tree reads them.
  factory LibraryPalette.of(ThemePalette t) => LibraryPalette(
    paper: t.paper,
    panel: t.panel,
    border: t.border,
    ink: t.ink,
    muted: t.muted,
    accent: t.accent,
    accentSoft: t.accentSoft,
    codeBackground: t.codeBackground,
    selection: t.selection,
  );

  @override
  LibraryPalette copyWith({
    Color? paper,
    Color? panel,
    Color? border,
    Color? ink,
    Color? muted,
    Color? accent,
    Color? accentSoft,
    Color? codeBackground,
    Color? selection,
  }) => LibraryPalette(
    paper: paper ?? this.paper,
    panel: panel ?? this.panel,
    border: border ?? this.border,
    ink: ink ?? this.ink,
    muted: muted ?? this.muted,
    accent: accent ?? this.accent,
    accentSoft: accentSoft ?? this.accentSoft,
    codeBackground: codeBackground ?? this.codeBackground,
    selection: selection ?? this.selection,
  );

  @override
  LibraryPalette lerp(LibraryPalette? other, double t) {
    if (other == null) return this;
    return LibraryPalette(
      paper: Color.lerp(paper, other.paper, t)!,
      panel: Color.lerp(panel, other.panel, t)!,
      border: Color.lerp(border, other.border, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      codeBackground: Color.lerp(codeBackground, other.codeBackground, t)!,
      selection: Color.lerp(selection, other.selection, t)!,
    );
  }
}

extension LibraryPaletteContext on BuildContext {
  LibraryPalette get palette => Theme.of(this).extension<LibraryPalette>()!;
}

/// The three voices of the page, resolved from the theme's family names.
/// Unknown families fall back to the library's own so a typo in a theme
/// file costs a font, not the app.
@immutable
final class LibraryTypefaces extends ThemeExtension<LibraryTypefaces> {
  final ThemeTypefaces families;

  const LibraryTypefaces(this.families);

  TextStyle serif({
    required Color color,
    double size = 18,
    double height = 1.7,
    FontWeight weight = FontWeight.w400,
    FontStyle style = FontStyle.normal,
  }) => _font(
    families.serif,
    ThemeTypefaces.library.serif,
    TextStyle(
      color: color,
      fontSize: size,
      height: height,
      fontWeight: weight,
      fontStyle: style,
    ),
  );

  TextStyle sans({
    required Color color,
    double size = 13.5,
    double height = 1.4,
    FontWeight weight = FontWeight.w400,
  }) => _font(
    families.sans,
    ThemeTypefaces.library.sans,
    TextStyle(color: color, fontSize: size, height: height, fontWeight: weight),
  );

  TextStyle mono({
    required Color color,
    double size = 14.5,
    double height = 1.6,
  }) => _font(
    families.mono,
    ThemeTypefaces.library.mono,
    TextStyle(color: color, fontSize: size, height: height),
  );

  /// Bundled families are used directly — no network, no flash of a fallback
  /// face, and metrics a test can measure. A theme may name any other family,
  /// which is fetched at runtime; if that fails, the library's own face stands
  /// in, so a typo in a theme file costs a font rather than the app.
  static TextStyle _font(String family, String fallback, TextStyle base) {
    base = base.copyWith(fontFamilyFallback: _readingFallbacks);
    if (bundledFontLicences.containsKey(family)) {
      final optical = bundledOpticalSizes[family];
      // The size asked for is a size of letters; this is the font size that
      // produces it in this particular face.
      final size = FontMetrics.sizeFor(family, base.fontSize ?? 16);
      return base.copyWith(
        fontFamily: family,
        fontSize: size,
        // Weight still reaches the `wght` axis through [TextStyle.fontWeight];
        // this only tells the face what size it is being drawn at.
        fontVariations: optical == null
            ? null
            : [FontVariation('opsz', size.clamp(optical.$1, optical.$2))],
      );
    }
    try {
      return GoogleFonts.getFont(family, textStyle: base);
    } on Exception {
      return base.copyWith(fontFamily: fallback);
    }
  }

  /// Native desktop reading faces for scripts and emoji outside the bundled
  /// Latin families. Flutter still falls back to the platform default after
  /// this list. CanvasKit owns a separate downloadable fallback on the web.
  static const _readingFallbacks = <String>[
    'Apple Color Emoji',
    'Segoe UI Emoji',
    'Noto Color Emoji',
    'SF Arabic',
    'Noto Sans Arabic',
    'SF Hebrew',
    'Noto Sans Hebrew',
    'PingFang SC',
    'Microsoft YaHei',
    'Noto Sans CJK SC',
    'Hiragino Sans',
    'Yu Gothic',
    'Meiryo',
    'Noto Sans Devanagari',
    'Noto Sans Tamil',
    'Noto Sans Thai',
  ];

  @override
  LibraryTypefaces copyWith({ThemeTypefaces? families}) =>
      LibraryTypefaces(families ?? this.families);

  @override
  LibraryTypefaces lerp(LibraryTypefaces? other, double t) =>
      t < 0.5 || other == null ? this : other;
}

extension LibraryTypefacesContext on BuildContext {
  LibraryTypefaces get type => Theme.of(this).extension<LibraryTypefaces>()!;
}

/// Material theme for a [ReaderTheme]: the palette and typefaces ride along
/// as extensions, and the few Material surfaces the app shows are tinted to match.
ThemeData libraryTheme(ReaderTheme theme) {
  final p = LibraryPalette.of(theme.palette);
  final type = LibraryTypefaces(theme.typefaces);
  return ThemeData(
    useMaterial3: true,
    brightness: theme.brightness,
    fontFamily: type.sans(color: p.ink).fontFamily,
    scaffoldBackgroundColor: p.paper,
    canvasColor: p.paper,
    dividerColor: p.border,
    splashFactory: NoSplash.splashFactory,
    colorScheme: ColorScheme.fromSeed(
      seedColor: p.accent,
      brightness: theme.brightness,
      primary: p.accent,
      surface: p.paper,
      onSurface: p.ink,
    ),
    iconTheme: IconThemeData(color: p.muted, size: 20),
    textSelectionTheme: TextSelectionThemeData(
      selectionColor: p.selection,
      cursorColor: p.accent,
    ),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 500),
      decoration: BoxDecoration(
        color: p.ink,
        borderRadius: BorderRadius.circular(6),
      ),
      textStyle: type.sans(color: p.paper, size: 12),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: p.panel,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: p.border),
      ),
    ),
    extensions: [p, type],
  );
}
