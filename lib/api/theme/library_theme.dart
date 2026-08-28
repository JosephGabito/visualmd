import 'package:flutter/material.dart';

import 'font_licences.dart';
import 'font_metrics.dart';

import '../../presentation/theme/reader_theme.dart';
import '../../presentation/theme/theme_palette.dart';
import '../../presentation/theme/theme_typefaces.dart';
import '../../presentation/theme/reading_mode.dart';
import 'library_chrome.dart';

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
    FontStyle style = FontStyle.normal,
  }) => _font(
    families.sans,
    ThemeTypefaces.library.sans,
    TextStyle(
      color: color,
      fontSize: size,
      height: height,
      fontWeight: weight,
      fontStyle: style,
    ),
  );

  /// The proportional face the reader chose for document content.
  ///
  /// Reading faces are a smaller contract than theme furniture: Serif accepts
  /// only the two bundled serifs whose metrics have been measured, while Sans
  /// is always Inter. A palette cannot silently replace a measured reading
  /// system with an arbitrary runtime font.
  TextStyle reading(
    ReadingMode mode, {
    required Color color,
    double size = 18,
    double height = 1.7,
    FontWeight weight = FontWeight.w400,
    FontStyle style = FontStyle.normal,
  }) {
    final family = switch (mode) {
      ReadingMode.serif when _serifReadingFamilies.contains(families.serif) =>
        families.serif,
      ReadingMode.serif => ThemeTypefaces.library.serif,
      ReadingMode.sans => ThemeTypefaces.library.sans,
    };
    return _font(
      family,
      mode == ReadingMode.serif
          ? ThemeTypefaces.library.serif
          : ThemeTypefaces.library.sans,
      TextStyle(
        color: color,
        fontSize: size,
        height: height,
        fontWeight: weight,
        fontStyle: style,
      ),
    );
  }

  TextStyle mono({
    required Color color,
    double size = 14.5,
    double height = 1.6,
  }) => _font(
    families.mono,
    ThemeTypefaces.library.mono,
    TextStyle(color: color, fontSize: size, height: height),
  );

  /// Only bundled, licensed and measured families are used. Unsupported theme
  /// names fall back locally; fonts are never fetched while someone is reading.
  static TextStyle _font(String family, String fallback, TextStyle base) {
    base = base.copyWith(fontFamilyFallback: _readingFallbacks);
    final resolved =
        bundledFontLicences.containsKey(family) &&
            FontMetrics.xHeights.containsKey(family)
        ? family
        : fallback;
    final optical = bundledOpticalSizes[resolved];
    // The size asked for is a size of letters; this is the font size that
    // produces it in this particular face.
    final size = FontMetrics.sizeFor(resolved, base.fontSize ?? 16);
    return base.copyWith(
      fontFamily: resolved,
      fontSize: size,
      // Weight still reaches the `wght` axis through [TextStyle.fontWeight];
      // this only tells the face what size it is being drawn at.
      fontVariations: optical == null
          ? null
          : [FontVariation('opsz', size.clamp(optical.$1, optical.$2))],
    );
  }

  static const _serifReadingFamilies = {'Alegreya', 'Literata'};

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

extension LibraryChromeContext on BuildContext {
  LibraryChrome get chrome {
    final theme = Theme.of(this);
    final authored = theme.extension<LibraryChrome>();
    if (authored != null) return authored;
    return LibraryChrome.fromMaterials(
      paper: theme.scaffoldBackgroundColor,
      panel: theme.colorScheme.surface,
      border: theme.dividerColor,
      ink: theme.colorScheme.onSurface,
      accent: theme.colorScheme.primary,
      brightness: theme.brightness,
    );
  }

  /// Short navigational text. All shelf and outline rows share this role.
  TextStyle chromeRow({Color? color, FontWeight weight = FontWeight.w400}) =>
      type.sans(
        color: color ?? palette.ink,
        size: 13.5,
        height: 1.18,
        weight: weight,
      );

  /// Supporting state or counts that must remain readable without competing.
  TextStyle get chromeMetadata =>
      type.sans(color: palette.muted, size: 12.5, height: 1.25);

  /// A compact structural label. Tracking restores the air removed by caps.
  TextStyle get chromeSectionLabel => type
      .sans(color: palette.muted, size: 11, height: 1, weight: FontWeight.w600)
      .copyWith(letterSpacing: 1.05);

  /// A component's identity, subordinate to the document around it.
  TextStyle get chromeComponentLabel => type.sans(
    color: palette.muted,
    size: 12,
    height: 1,
    weight: FontWeight.w600,
  );
}

/// Material theme for a [ReaderTheme]: the palette and typefaces ride along
/// as extensions, and the few Material surfaces the app shows are tinted to match.
ThemeData libraryTheme(ReaderTheme theme) {
  final p = LibraryPalette.of(theme.palette);
  final type = LibraryTypefaces(theme.typefaces);
  final chrome = LibraryChrome.fromMaterials(
    paper: p.paper,
    panel: p.panel,
    border: p.border,
    ink: p.ink,
    accent: p.accent,
    brightness: theme.brightness,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: theme.brightness,
    fontFamily: type.sans(color: p.ink).fontFamily,
    scaffoldBackgroundColor: p.paper,
    canvasColor: p.paper,
    dividerColor: chrome.separator,
    splashFactory: NoSplash.splashFactory,
    colorScheme: ColorScheme.fromSeed(
      seedColor: p.accent,
      brightness: theme.brightness,
      primary: p.accent,
      surface: p.paper,
      onSurface: p.ink,
    ),
    iconTheme: IconThemeData(color: p.muted, size: 20),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(
          Size.square(LibraryChromeScale.control),
        ),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const WidgetStatePropertyAll(EdgeInsets.all(5)),
        foregroundColor: WidgetStatePropertyAll(p.muted),
        overlayColor: WidgetStateColor.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) return chrome.pressed;
          if (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.focused)) {
            return chrome.hover;
          }
          return Colors.transparent;
        }),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              LibraryChromeScale.controlRadius,
            ),
          ),
        ),
      ),
    ),
    textSelectionTheme: TextSelectionThemeData(
      selectionColor: p.selection,
      cursorColor: p.accent,
    ),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 500),
      decoration: BoxDecoration(
        color: p.ink,
        borderRadius: BorderRadius.circular(LibraryChromeScale.controlRadius),
      ),
      textStyle: type.sans(color: p.paper, size: 12),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: p.panel,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LibraryChromeScale.floatingRadius),
        side: BorderSide(color: chrome.separator),
      ),
    ),
    extensions: [p, type, chrome],
  );
}
