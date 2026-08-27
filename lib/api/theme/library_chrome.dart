import 'package:flutter/material.dart';

/// The small, fixed scale used by the room around the document.
///
/// The reading page owns a typographic rhythm. Chrome needs a quieter system
/// of its own: close values are deliberately omitted so a contributor chooses
/// a relationship, not an arbitrary pixel that happens to look plausible.
abstract final class LibraryChromeScale {
  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space5 = 24;

  static const double control = 30;
  static const double row = 32;

  // macOS window corners are the largest curve in the room. Interior shapes
  // step down from that silhouette instead of each widget inventing a radius.
  static const double windowRadius = 10;
  static const double floatingRadius = 10;
  static const double componentRadius = 8;
  static const double controlRadius = 6;
  static const double rowRadius = 6;
  static const double smallRadius = 4;
}

/// Semantic chrome colours derived from a reader theme's authored materials.
///
/// Theme files describe the document and its room with a compact palette. The
/// interface needs more roles than that file format should expose, so opaque
/// intermediate tones are mixed here once. This keeps hover, selection,
/// separators and elevation consistent across every built-in and user theme.
@immutable
final class LibraryChrome extends ThemeExtension<LibraryChrome> {
  final Color topBar;
  final Color panel;
  final Color separator;
  final Color hover;
  final Color pressed;
  final Color selected;
  final Color selectedHover;
  final Color elevated;
  final Color focus;
  final Color shadow;

  const LibraryChrome({
    required this.topBar,
    required this.panel,
    required this.separator,
    required this.hover,
    required this.pressed,
    required this.selected,
    required this.selectedHover,
    required this.elevated,
    required this.focus,
    required this.shadow,
  });

  factory LibraryChrome.fromMaterials({
    required Color paper,
    required Color panel,
    required Color border,
    required Color ink,
    required Color accent,
    required Brightness brightness,
  }) {
    final dark = brightness == Brightness.dark;
    // A sidebar is a material, not paper with a rule drawn beside it. Pulling
    // the authored panel a measured step toward ink gives the window a clear
    // frame on both light and dark themes without introducing another token.
    final sidebar = Color.lerp(panel, ink, dark ? 0.035 : 0.02)!;
    return LibraryChrome(
      // The unified title bar belongs to the window frame rather than the
      // document, so it sits closer to the sidebars than to paper.
      topBar: Color.lerp(paper, sidebar, dark ? 0.68 : 0.62)!,
      panel: sidebar,
      separator: Color.lerp(sidebar, border, dark ? 0.66 : 0.52)!,
      // Hover is neutral. Accent is reserved for location and focus.
      hover: Color.lerp(sidebar, ink, dark ? 0.075 : 0.045)!,
      pressed: Color.lerp(sidebar, ink, dark ? 0.13 : 0.085)!,
      selected: _legibleTint(
        surface: sidebar,
        tint: accent,
        foreground: ink,
        maximum: dark ? 0.30 : 0.19,
      ),
      selectedHover: _legibleTint(
        surface: sidebar,
        tint: accent,
        foreground: ink,
        maximum: dark ? 0.36 : 0.25,
      ),
      // Floating surfaces move one opaque step toward the page. Shadows then
      // describe actual elevation rather than outlining every component.
      elevated: Color.lerp(sidebar, paper, dark ? 0.24 : 0.68)!,
      focus: accent,
      shadow: Colors.black.withValues(alpha: dark ? 0.34 : 0.16),
    );
  }

  @override
  LibraryChrome copyWith({
    Color? topBar,
    Color? panel,
    Color? separator,
    Color? hover,
    Color? pressed,
    Color? selected,
    Color? selectedHover,
    Color? elevated,
    Color? focus,
    Color? shadow,
  }) => LibraryChrome(
    topBar: topBar ?? this.topBar,
    panel: panel ?? this.panel,
    separator: separator ?? this.separator,
    hover: hover ?? this.hover,
    pressed: pressed ?? this.pressed,
    selected: selected ?? this.selected,
    selectedHover: selectedHover ?? this.selectedHover,
    elevated: elevated ?? this.elevated,
    focus: focus ?? this.focus,
    shadow: shadow ?? this.shadow,
  );

  @override
  LibraryChrome lerp(LibraryChrome? other, double t) {
    if (other == null) return this;
    return LibraryChrome(
      topBar: Color.lerp(topBar, other.topBar, t)!,
      panel: Color.lerp(panel, other.panel, t)!,
      separator: Color.lerp(separator, other.separator, t)!,
      hover: Color.lerp(hover, other.hover, t)!,
      pressed: Color.lerp(pressed, other.pressed, t)!,
      selected: Color.lerp(selected, other.selected, t)!,
      selectedHover: Color.lerp(selectedHover, other.selectedHover, t)!,
      elevated: Color.lerp(elevated, other.elevated, t)!,
      focus: Color.lerp(focus, other.focus, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}

Color _legibleTint({
  required Color surface,
  required Color tint,
  required Color foreground,
  required double maximum,
}) {
  for (var amount = maximum; amount >= 0; amount -= 0.01) {
    final candidate = Color.lerp(surface, tint, amount)!;
    final lighter = foreground.computeLuminance() > candidate.computeLuminance()
        ? foreground.computeLuminance()
        : candidate.computeLuminance();
    final darker = foreground.computeLuminance() > candidate.computeLuminance()
        ? candidate.computeLuminance()
        : foreground.computeLuminance();
    if ((lighter + 0.05) / (darker + 0.05) >= 4.5) return candidate;
  }
  return surface;
}
