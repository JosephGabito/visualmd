import 'dart:ui' show Brightness, Color;

import 'reader_theme.dart';
import 'theme_family.dart';
import 'theme_palette.dart';

/// Familiar light and dark palette families adapted from editor and product
/// surfaces to Visual MD's reader semantics.
///
/// Source backgrounds, ink, and characteristic hues keep each palette's
/// identity. Muted and accent colours move only as far as needed to remain
/// readable at 4.5:1 on both the page and panel; typography stays Visual MD's.
abstract final class CodexThemeCollection {
  static const absolutelyLight = ReaderTheme(
    id: 'absolutely-light',
    name: 'Absolutely Light',
    brightness: Brightness.light,
    palette: ThemePalette(
      paper: Color(0xFFF9F9F7),
      panel: Color(0xFFF4F4F2),
      border: Color(0xFFDEDEDB),
      ink: Color(0xFF2D2D2B),
      muted: Color(0xFF6F6F6D),
      accent: Color(0xFF98634D),
      codeBackground: Color(0xFFF4F4F2),
      accentSoft: Color(0xFFE6DBD5),
      selection: Color(0x4D98634D),
    ),
  );

  static const absolutelyDark = ReaderTheme(
    id: 'absolutely-dark',
    name: 'Absolutely Dark',
    brightness: Brightness.dark,
    palette: ThemePalette(
      paper: Color(0xFF2D2D2B),
      panel: Color(0xFF373735),
      border: Color(0xFF4B4B48),
      ink: Color(0xFFF9F9F7),
      muted: Color(0xFFB2B2B0),
      accent: Color(0xFFD28F74),
      codeBackground: Color(0xFF373735),
      accentSoft: Color(0xFF4E413A),
      selection: Color(0x4DD28F74),
    ),
  );

  static const catppuccinLatte = ReaderTheme(
    id: 'catppuccin-latte',
    name: 'Catppuccin Latte',
    brightness: Brightness.light,
    palette: ThemePalette(
      paper: Color(0xFFEFF1F5),
      panel: Color(0xFFE6E9EF),
      border: Color(0xFFCCD0DA),
      ink: Color(0xFF4C4F69),
      muted: Color(0xFF64677E),
      accent: Color(0xFF8739EC),
      codeBackground: Color(0xFFE6E9EF),
      accentSoft: Color(0xFFDACCF3),
      selection: Color(0x4D8739EC),
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
      muted: Color(0xFF9399B2),
      accent: Color(0xFFCBA6F7),
      codeBackground: Color(0xFF181825),
      accentSoft: Color(0xFF413956),
      selection: Color(0x4DCBA6F7),
    ),
  );

  static const codexLight = ReaderTheme(
    id: 'codex-light',
    name: 'Codex Light',
    brightness: Brightness.light,
    palette: ThemePalette(
      paper: Color(0xFFFFFFFF),
      panel: Color(0xFFFCFCFC),
      border: Color(0xFFE5E5E5),
      ink: Color(0xFF0D0D0D),
      muted: Color(0xFF666666),
      accent: Color(0xFF0169CC),
      codeBackground: Color(0xFFFCFCFC),
      accentSoft: Color(0xFFCCE1F5),
      selection: Color(0x4D0169CC),
    ),
  );

  static const codexDark = ReaderTheme(
    id: 'codex-dark',
    name: 'Codex Dark',
    brightness: Brightness.dark,
    palette: ThemePalette(
      paper: Color(0xFF111111),
      panel: Color(0xFF131313),
      border: Color(0xFF2B2B2B),
      ink: Color(0xFFFCFCFC),
      muted: Color(0xFF999999),
      accent: Color(0xFF3D8DFF),
      codeBackground: Color(0xFF131313),
      accentSoft: Color(0xFF1A2A41),
      selection: Color(0x4D3D8DFF),
    ),
  );

  static const everforestLight = ReaderTheme(
    id: 'everforest-light',
    name: 'Everforest Light',
    brightness: Brightness.light,
    palette: ThemePalette(
      paper: Color(0xFFFDF6E3),
      panel: Color(0xFFF4F0D9),
      border: Color(0xFFE0DCC7),
      ink: Color(0xFF5C6A72),
      muted: Color(0xFF626F75),
      accent: Color(0xFF627164),
      codeBackground: Color(0xFFF4F0D9),
      accentSoft: Color(0xFFDEDBCA),
      selection: Color(0x4D627164),
    ),
  );

  static const everforestDark = ReaderTheme(
    id: 'everforest-dark',
    name: 'Everforest Dark',
    brightness: Brightness.dark,
    palette: ThemePalette(
      paper: Color(0xFF2D353B),
      panel: Color(0xFF343F44),
      border: Color(0xFF475258),
      ink: Color(0xFFD3C6AA),
      muted: Color(0xFFA7A998),
      accent: Color(0xFFA7C080),
      codeBackground: Color(0xFF343F44),
      accentSoft: Color(0xFF455149),
      selection: Color(0x4DA7C080),
    ),
  );

  static const githubLight = ReaderTheme(
    id: 'github-light',
    name: 'GitHub Light',
    brightness: Brightness.light,
    palette: ThemePalette(
      paper: Color(0xFFFFFFFF),
      panel: Color(0xFFF6F8FA),
      border: Color(0xFFD0D7DE),
      ink: Color(0xFF1F2328),
      muted: Color(0xFF6A737D),
      accent: Color(0xFF0969DA),
      codeBackground: Color(0xFFF6F8FA),
      accentSoft: Color(0xFFCEE1F8),
      selection: Color(0x4D0969DA),
    ),
  );

  static const githubDark = ReaderTheme(
    id: 'github-dark',
    name: 'GitHub Dark',
    brightness: Brightness.dark,
    palette: ThemePalette(
      paper: Color(0xFF0D1117),
      panel: Color(0xFF010409),
      border: Color(0xFF30363D),
      ink: Color(0xFFE6EDF3),
      muted: Color(0xFF8B949E),
      accent: Color(0xFF58A6FF),
      codeBackground: Color(0xFF161B22),
      accentSoft: Color(0xFF1C2F45),
      selection: Color(0x4D58A6FF),
    ),
  );

  static const gruvboxLight = ReaderTheme(
    id: 'gruvbox-light',
    name: 'Gruvbox Light',
    brightness: Brightness.light,
    palette: ThemePalette(
      paper: Color(0xFFFBF1C7),
      panel: Color(0xFFEBDBB2),
      border: Color(0xFFD5C4A1),
      ink: Color(0xFF3C3836),
      muted: Color(0xFF695F56),
      accent: Color(0xFF076678),
      codeBackground: Color(0xFFEBDBB2),
      accentSoft: Color(0xFFCAD5B7),
      selection: Color(0x4D076678),
    ),
  );

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
      accent: Color(0xFF83A598),
      codeBackground: Color(0xFF1D2021),
      accentSoft: Color(0xFF3A413E),
      selection: Color(0x4D83A598),
    ),
  );

  static const linearLight = ReaderTheme(
    id: 'linear-light',
    name: 'Linear Light',
    brightness: Brightness.light,
    palette: ThemePalette(
      paper: Color(0xFFF7F8FA),
      panel: Color(0xFFF2F4F8),
      border: Color(0xFFDFE3EB),
      ink: Color(0xFF2A3140),
      muted: Color(0xFF677081),
      accent: Color(0xFF5B67C9),
      codeBackground: Color(0xFFF2F4F8),
      accentSoft: Color(0xFFD8DBF0),
      selection: Color(0x4D5B67C9),
    ),
  );

  static const linearDark = ReaderTheme(
    id: 'linear-dark',
    name: 'Linear Dark',
    brightness: Brightness.dark,
    palette: ThemePalette(
      paper: Color(0xFF17181D),
      panel: Color(0xFF0A0C11),
      border: Color(0xFF2B2F3A),
      ink: Color(0xFFE6E9EF),
      muted: Color(0xFF7B8290),
      accent: Color(0xFF8C97FF),
      codeBackground: Color(0xFF0F1219),
      accentSoft: Color(0xFF2E314A),
      selection: Color(0x4D8C97FF),
    ),
  );

  static const notionLight = ReaderTheme(
    id: 'notion-light',
    name: 'Notion Light',
    brightness: Brightness.light,
    palette: ThemePalette(
      paper: Color(0xFFFFFFFF),
      panel: Color(0xFFF7F6F3),
      border: Color(0xFFE3E2DF),
      ink: Color(0xFF37352F),
      muted: Color(0xFF4F4B45),
      accent: Color(0xFF3273B6),
      codeBackground: Color(0xFFF7F6F3),
      accentSoft: Color(0xFFD6E3F0),
      selection: Color(0x4D3273B6),
    ),
  );

  static const notionDark = ReaderTheme(
    id: 'notion-dark',
    name: 'Notion Dark',
    brightness: Brightness.dark,
    palette: ThemePalette(
      paper: Color(0xFF191919),
      panel: Color(0xFF151515),
      border: Color(0xFF333333),
      ink: Color(0xFFD9D9D8),
      muted: Color(0xFF9B9A97),
      accent: Color(0xFF529CCA),
      codeBackground: Color(0xFF151515),
      accentSoft: Color(0xFF24333C),
      selection: Color(0x4D529CCA),
    ),
  );

  static const oneLight = ReaderTheme(
    id: 'one-light',
    name: 'One Light',
    brightness: Brightness.light,
    palette: ThemePalette(
      paper: Color(0xFFFAFAFA),
      panel: Color(0xFFEAEAEB),
      border: Color(0xFFDBDBDC),
      ink: Color(0xFF383A42),
      muted: Color(0xFF686970),
      accent: Color(0xFF4B61CC),
      codeBackground: Color(0xFFEAEAEB),
      accentSoft: Color(0xFFD7DBF1),
      selection: Color(0x4D4B61CC),
    ),
  );

  static const oneDark = ReaderTheme(
    id: 'one-dark',
    name: 'One Dark',
    brightness: Brightness.dark,
    palette: ThemePalette(
      paper: Color(0xFF282C34),
      panel: Color(0xFF21252B),
      border: Color(0xFF3E4452),
      ink: Color(0xFFABB2BF),
      muted: Color(0xFF8C93A0),
      accent: Color(0xFF61AFEF),
      codeBackground: Color(0xFF21252B),
      accentSoft: Color(0xFF334659),
      selection: Color(0x4D61AFEF),
    ),
  );

  static const proofLight = ReaderTheme(
    id: 'proof-light',
    name: 'Proof Light',
    brightness: Brightness.light,
    palette: ThemePalette(
      paper: Color(0xFFF5F3ED),
      panel: Color(0xFFEFEDE6),
      border: Color(0xFFDAD7CD),
      ink: Color(0xFF2F312D),
      muted: Color(0xFF6E6B63),
      accent: Color(0xFF3D755D),
      codeBackground: Color(0xFFEFEDE6),
      accentSoft: Color(0xFFD0DAD0),
      selection: Color(0x4D3D755D),
    ),
  );

  static const raycastLight = ReaderTheme(
    id: 'raycast-light',
    name: 'Raycast Light',
    brightness: Brightness.light,
    palette: ThemePalette(
      paper: Color(0xFFFFFFFF),
      panel: Color(0xFFFCFCFC),
      border: Color(0xFFE4E4E4),
      ink: Color(0xFF000000),
      muted: Color(0xFF747474),
      accent: Color(0xFFC03030),
      codeBackground: Color(0xFFFCFCFC),
      accentSoft: Color(0xFFF2D6D6),
      selection: Color(0x4DC03030),
    ),
  );

  static const raycastDark = ReaderTheme(
    id: 'raycast-dark',
    name: 'Raycast Dark',
    brightness: Brightness.dark,
    palette: ThemePalette(
      paper: Color(0xFF141414),
      panel: Color(0xFF101010),
      border: Color(0xFF303030),
      ink: Color(0xFFFFFFFF),
      muted: Color(0xFF999999),
      accent: Color(0xFFFF6363),
      codeBackground: Color(0xFF101010),
      accentSoft: Color(0xFF432424),
      selection: Color(0x4DFF6363),
    ),
  );

  static const rosePineDawn = ReaderTheme(
    id: 'rose-pine-dawn',
    name: 'Rosé Pine Dawn',
    brightness: Brightness.light,
    palette: ThemePalette(
      paper: Color(0xFFFAF4ED),
      panel: Color(0xFFFFFAF3),
      border: Color(0xFFF2E9E1),
      ink: Color(0xFF575279),
      muted: Color(0xFF716C8A),
      accent: Color(0xFF8A657B),
      codeBackground: Color(0xFFFFFAF3),
      accentSoft: Color(0xFFE4D7D6),
      selection: Color(0x4D8A657B),
    ),
  );

  static const rosePineMoon = ReaderTheme(
    id: 'rose-pine-moon',
    name: 'Rosé Pine Moon',
    brightness: Brightness.dark,
    palette: ThemePalette(
      paper: Color(0xFF232136),
      panel: Color(0xFF2A273F),
      border: Color(0xFF393552),
      ink: Color(0xFFE0DEF4),
      muted: Color(0xFF918DAB),
      accent: Color(0xFFEA9A97),
      codeBackground: Color(0xFF2A273F),
      accentSoft: Color(0xFF4B3949),
      selection: Color(0x4DEA9A97),
    ),
  );

  static const solarizedLight = ReaderTheme(
    id: 'solarized-light',
    name: 'Solarized Light',
    brightness: Brightness.light,
    palette: ThemePalette(
      paper: Color(0xFFFDF6E3),
      panel: Color(0xFFEEE8D5),
      border: Color(0xFFDDD6C1),
      ink: Color(0xFF4F6268),
      muted: Color(0xFF586C73),
      accent: Color(0xFF786400),
      codeBackground: Color(0xFFEEE8D5),
      accentSoft: Color(0xFFE2D9B6),
      selection: Color(0x4D786400),
    ),
  );

  static const solarizedDark = ReaderTheme(
    id: 'solarized-dark',
    name: 'Solarized Dark',
    brightness: Brightness.dark,
    palette: ThemePalette(
      paper: Color(0xFF002B36),
      panel: Color(0xFF00212B),
      border: Color(0xFF073642),
      ink: Color(0xFF839496),
      muted: Color(0xFF7F9093),
      accent: Color(0xFFB58900),
      codeBackground: Color(0xFF00212B),
      accentSoft: Color(0xFF243E2B),
      selection: Color(0x4DB58900),
    ),
  );

  static const vercelLight = ReaderTheme(
    id: 'vercel-light',
    name: 'Vercel Light',
    brightness: Brightness.light,
    palette: ThemePalette(
      paper: Color(0xFFFFFFFF),
      panel: Color(0xFFFAFAFA),
      border: Color(0xFFEAEAEA),
      ink: Color(0xFF171717),
      muted: Color(0xFF666666),
      accent: Color(0xFF0069FD),
      codeBackground: Color(0xFFFAFAFA),
      accentSoft: Color(0xFFCCE1FF),
      selection: Color(0x4D0069FD),
    ),
  );

  static const vercelDark = ReaderTheme(
    id: 'vercel-dark',
    name: 'Vercel Dark',
    brightness: Brightness.dark,
    palette: ThemePalette(
      paper: Color(0xFF000000),
      panel: Color(0xFF111111),
      border: Color(0xFF2E2E2E),
      ink: Color(0xFFEDEDED),
      muted: Color(0xFFA1A1A1),
      accent: Color(0xFF3291FF),
      codeBackground: Color(0xFF111111),
      accentSoft: Color(0xFF0A1D33),
      selection: Color(0x4D3291FF),
    ),
  );

  static const vscodePlusLight = ReaderTheme(
    id: 'vscode-plus-light',
    name: 'VS Code Plus Light',
    brightness: Brightness.light,
    palette: ThemePalette(
      paper: Color(0xFFFFFFFF),
      panel: Color(0xFFF3F3F3),
      border: Color(0xFFD4D4D4),
      ink: Color(0xFF000000),
      muted: Color(0xFF616161),
      accent: Color(0xFF0073C0),
      codeBackground: Color(0xFFF3F3F3),
      accentSoft: Color(0xFFCCE3F2),
      selection: Color(0x4D0073C0),
    ),
  );

  static const vscodePlusDark = ReaderTheme(
    id: 'vscode-plus-dark',
    name: 'VS Code Plus Dark',
    brightness: Brightness.dark,
    palette: ThemePalette(
      paper: Color(0xFF1E1E1E),
      panel: Color(0xFF252526),
      border: Color(0xFF3F3F46),
      ink: Color(0xFFD4D4D4),
      muted: Color(0xFF8C8C8C),
      accent: Color(0xFF3794FF),
      codeBackground: Color(0xFF252526),
      accentSoft: Color(0xFF23364B),
      selection: Color(0x4D3794FF),
    ),
  );

  static const xcodeLight = ReaderTheme(
    id: 'xcode-light',
    name: 'Xcode Light',
    brightness: Brightness.light,
    palette: ThemePalette(
      paper: Color(0xFFFFFFFF),
      panel: Color(0xFFF5F5F7),
      border: Color(0xFFD8D8DC),
      ink: Color(0xFF1F1F24),
      muted: Color(0xFF5D6C79),
      accent: Color(0xFF0E0EFF),
      codeBackground: Color(0xFFF5F5F7),
      accentSoft: Color(0xFFCFCFFF),
      selection: Color(0x4D0E0EFF),
    ),
  );

  static const xcodeDark = ReaderTheme(
    id: 'xcode-dark',
    name: 'Xcode Dark',
    brightness: Brightness.dark,
    palette: ThemePalette(
      paper: Color(0xFF1F1F24),
      panel: Color(0xFF29292E),
      border: Color(0xFF3B3B42),
      ink: Color(0xFFEDEDF0),
      muted: Color(0xFF87919C),
      accent: Color(0xFF608BFE),
      codeBackground: Color(0xFF29292E),
      accentSoft: Color(0xFF2C3550),
      selection: Color(0x4D608BFE),
    ),
  );

  static const all = [
    absolutelyLight,
    absolutelyDark,
    catppuccinLatte,
    catppuccinMocha,
    codexLight,
    codexDark,
    everforestLight,
    everforestDark,
    githubLight,
    githubDark,
    gruvboxLight,
    gruvboxDark,
    linearLight,
    linearDark,
    notionLight,
    notionDark,
    oneLight,
    oneDark,
    proofLight,
    raycastLight,
    raycastDark,
    rosePineDawn,
    rosePineMoon,
    solarizedLight,
    solarizedDark,
    vercelLight,
    vercelDark,
    vscodePlusLight,
    vscodePlusDark,
    xcodeLight,
    xcodeDark,
  ];

  static const families = [
    ThemeFamily(
      name: 'Absolutely',
      light: 'absolutely-light',
      dark: 'absolutely-dark',
    ),
    ThemeFamily(
      name: 'Catppuccin',
      light: 'catppuccin-latte',
      dark: 'catppuccin-mocha',
    ),
    ThemeFamily(name: 'Codex', light: 'codex-light', dark: 'codex-dark'),
    ThemeFamily(
      name: 'Everforest',
      light: 'everforest-light',
      dark: 'everforest-dark',
    ),
    ThemeFamily(name: 'GitHub', light: 'github-light', dark: 'github-dark'),
    ThemeFamily(name: 'Gruvbox', light: 'gruvbox-light', dark: 'gruvbox-dark'),
    ThemeFamily(name: 'Linear', light: 'linear-light', dark: 'linear-dark'),
    ThemeFamily(name: 'Notion', light: 'notion-light', dark: 'notion-dark'),
    ThemeFamily(name: 'One', light: 'one-light', dark: 'one-dark'),
    ThemeFamily(name: 'Proof', light: 'proof-light'),
    ThemeFamily(name: 'Raycast', light: 'raycast-light', dark: 'raycast-dark'),
    ThemeFamily(
      name: 'Rose Pine',
      light: 'rose-pine-dawn',
      dark: 'rose-pine-moon',
    ),
    ThemeFamily(
      name: 'Solarized',
      light: 'solarized-light',
      dark: 'solarized-dark',
    ),
    ThemeFamily(name: 'Vercel', light: 'vercel-light', dark: 'vercel-dark'),
    ThemeFamily(
      name: 'VS Code Plus',
      light: 'vscode-plus-light',
      dark: 'vscode-plus-dark',
    ),
    ThemeFamily(name: 'Xcode', light: 'xcode-light', dark: 'xcode-dark'),
  ];
}
