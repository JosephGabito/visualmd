import 'dart:ui' show Brightness, Color;

import 'reader_theme.dart';
import 'theme_palette.dart';

/// The themes the reader ships with. The first light and the first dark one
/// are the defaults the "follow system" pair starts from.
abstract final class BuiltInThemes {
  static const paper = ReaderTheme(
    id: 'paper',
    name: 'Paper',
    brightness: Brightness.light,
    palette: ThemePalette(
      paper: Color(0xFFF8F4EB),
      panel: Color(0xFFF0EADD),
      border: Color(0xFFE2DAC7),
      ink: Color(0xFF2B2925),
      muted: Color(0xFF70695C),
      accent: Color(0xFFA65A2E),
      codeBackground: Color(0xFFEDE6D4),
      accentSoft: Color(0xFFF1E2D3),
      selection: Color(0x40A65A2E),
    ),
  );

  static const lamplight = ReaderTheme(
    id: 'lamplight',
    name: 'Lamplight',
    brightness: Brightness.dark,
    palette: ThemePalette(
      paper: Color(0xFF1E1B16),
      panel: Color(0xFF24201A),
      border: Color(0xFF38312A),
      ink: Color(0xFFE9E1D0),
      muted: Color(0xFF9F9685),
      accent: Color(0xFFDFA273),
      codeBackground: Color(0xFF2A241D),
      accentSoft: Color(0xFF3A2D22),
      selection: Color(0x4DDFA273),
    ),
  );

  // Catppuccin (MIT) — https://github.com/catppuccin/palette
  static const catppuccinLatte = ReaderTheme(
    id: 'catppuccin-latte',
    name: 'Catppuccin Latte',
    brightness: Brightness.light,
    palette: ThemePalette(
      paper: Color(0xFFEFF1F5),
      panel: Color(0xFFE6E9EF),
      border: Color(0xFFCCD0DA),
      ink: Color(0xFF4C4F69),
      muted: Color(0xFF5C5F77),
      accent: Color(0xFF8839EF),
      codeBackground: Color(0xFFE6E9EF),
      accentSoft: Color(0xFFDACCF4),
      selection: Color(0x4D8839EF),
    ),
  );

  static const catppuccinMocha = ReaderTheme(
    id: 'catppuccin-mocha',
    name: 'Catppuccin Mocha',
    brightness: Brightness.dark,
    palette: ThemePalette(
      paper: Color(0xFF1E1E2E),
      panel: Color(0xFF181825),
      border: Color(0xFF313244),
      ink: Color(0xFFCDD6F4),
      muted: Color(0xFFA6ADC8),
      accent: Color(0xFFFAB387),
      codeBackground: Color(0xFF181825),
      accentSoft: Color(0xFF3A2F33),
      selection: Color(0x4DFAB387),
    ),
  );

  // Nord (MIT) — https://www.nordtheme.com
  static const nord = ReaderTheme(
    id: 'nord',
    name: 'Nord',
    brightness: Brightness.dark,
    palette: ThemePalette(
      paper: Color(0xFF2E3440),
      panel: Color(0xFF3B4252),
      border: Color(0xFF434C5E),
      ink: Color(0xFFECEFF4),
      muted: Color(0xFFAAB3C6),
      accent: Color(0xFF88C0D0),
      codeBackground: Color(0xFF3B4252),
      accentSoft: Color(0xFF3F505C),
      selection: Color(0x4D88C0D0),
    ),
  );

  // Gruvbox (MIT) — https://github.com/morhetz/gruvbox
  static const gruvboxDark = ReaderTheme(
    id: 'gruvbox-dark',
    name: 'Gruvbox Dark',
    brightness: Brightness.dark,
    palette: ThemePalette(
      paper: Color(0xFF282828),
      panel: Color(0xFF1D2021),
      border: Color(0xFF3C3836),
      ink: Color(0xFFEBDBB2),
      muted: Color(0xFFA89984),
      accent: Color(0xFFFE8019),
      codeBackground: Color(0xFF1D2021),
      accentSoft: Color(0xFF4A3826),
      selection: Color(0x4DFE8019),
    ),
  );

  static const all = [
    paper,
    lamplight,
    catppuccinLatte,
    catppuccinMocha,
    nord,
    gruvboxDark,
  ];

  static const defaultLight = paper;
  static const defaultDark = lamplight;
}
