# Theme Binding

The [presentation](../04-presentation/README.md) ring says what a theme *is*;
this document covers what Flutter does with it. Two `ThemeExtension`s carry a
theme's tokens and typefaces into the widget tree, and one function builds the
`ThemeData` from them. Turning those tokens and the
[reading scale](../04-presentation/07-reading-scale.md) into the styles the
page is set with is a step further out, in
[Reading Theme](14-reading-theme.md).

For the contract itself — tokens, typefaces, the JSON format — see
[ReaderTheme](../04-presentation/01-reader-theme.md) and
[ThemePalette](../04-presentation/02-theme-palette.md). To write a theme, see
[Creating a Theme](../09-contributing/05-creating-a-theme.md).

## The two extensions

`LibraryPalette` (`lib/api/theme/library_theme.dart:12-88`) is the nine tokens
as the widget tree reads them, plus the `copyWith` and `lerp` pair Flutter
needs to animate a theme change (`lib/api/theme/library_theme.dart:49-87`).
It is built from a `ThemePalette` by `LibraryPalette.of`
(`lib/api/theme/library_theme.dart:36-47`) and read anywhere as
`context.palette` (`lib/api/theme/library_theme.dart:90-92`).

The duplication between `ThemePalette` and `LibraryPalette` is deliberate: the
contract stays framework-free, and Flutter's theming machinery gets the
`ThemeExtension` subclass it requires. `LibraryPalette.of` is the whole bridge.

`LibraryTypefaces` (`lib/api/theme/library_theme.dart:97-157`) holds the
theme's three family names and hands out text styles:

| Voice | Signature | Citation |
|-------|-----------|----------|
| `serif` | colour, size, height, weight, style | `lib/api/theme/library_theme.dart:103-111` |
| `sans` | colour, size, height, weight | `lib/api/theme/library_theme.dart:113-120` |
| `mono` | colour, size, height | `lib/api/theme/library_theme.dart:122-124` |

Sizes belong to the reading design, not to the theme — a theme changes the
voice, never the rhythm. Read as `context.type`
(`lib/api/theme/library_theme.dart:178-180`).

## Fonts are bundled, not fetched

Alegreya, Literata, Inter and JetBrains Mono ship inside the app as variable
TTFs, with their italics, declared in `pubspec.yaml:39-57`. Three reasons, in
order of weight: a reader must be able to draw text with no network; there is no flash
of a fallback face at launch; and the metrics become deterministic enough to
measure in a test, which is what the
[reading scale](../04-presentation/07-reading-scale.md) is built on.

All four are SIL Open Font License 1.1 with no reserved font names, so bundling
is permitted, and the licence obliges the notice to travel with the fonts: the
four OFL files ship as assets (`pubspec.yaml:28-34`) and
`registerFontLicences()` adds them to the registry behind `showLicensePage`
(`lib/api/theme/font_licences.dart:13-24`), called once at startup
(`lib/main.dart:21`).

`GoogleFonts` is now only a fallback. A bundled family is used directly; a
family a theme names that we do not ship is fetched at runtime, and if that
fails the library's own face stands in
(`lib/api/theme/library_theme.dart:127-152`). A typo in a theme file costs a
font, not the app.

## The reading face, and what a size means

`ThemeTypefaces.library` names Alegreya for reading — drawn for literature and
long-form text — with Inter for the furniture and JetBrains Mono for code
(`lib/presentation/theme/theme_typefaces.dart:12-19`). Literata stays bundled
and selectable: a theme may name it, and `?serif=<family>` overrides the reading
face for one run (`lib/main.dart:81-86`, applied by `VisualMdApp._wearing` at
`lib/api/app.dart:38-56`), which is for judging a face on a real document and so
is not persisted.

A bundled family is not set at the size asked for: that size is a size of
*letters*, and [Font Metrics](16-font-metrics.md) works out the font size
producing it in that face (`lib/api/theme/library_theme.dart:134-139`) — the
same "18" is 21.9 px in Alegreya and 19.5 px in Literata. Line height is derived
from the face's metrics too, in [Reading Theme](14-reading-theme.md).

## Optical size

A face with an `opsz` axis is not one design but several: at reading sizes the
letters are wider and the strokes sturdier, at display sizes they tighten and
the hairlines thin. `bundledOpticalSizes` records each face's axis range —
Literata 7–72, Inter 14–32 (`lib/api/theme/font_licences.dart:25-35`) — and
`_font` hands the axis the size actually being drawn, clamped to that range
(`lib/api/theme/library_theme.dart:133-144`). It is the difference between a
font that has been scaled and one that has been designed.

Two facts were measured before relying on it
(`test/typography_measure_test.dart:53-78`): `TextStyle.fontWeight` still
reaches the `wght` axis when `fontVariations` sets only `opsz`, so weight stays
ordinary Flutter; and the axis does real work — at 18 px the display cut
(`opsz` 60) sets about 2 % narrower than the default, the small-text cut
(`opsz` 8) about 9 % wider. Neither JetBrains Mono nor Alegreya has the axis,
so both are left alone (`lib/api/theme/font_licences.dart:32-35`) — the reading
face gets no display cut at heading sizes, the one thing Literata does that it
does not.

## Building the ThemeData

`libraryTheme(ReaderTheme)` (`lib/api/theme/library_theme.dart:165-200`) is the
single entry point: `VisualMdApp` calls it for the light and dark slots and lets
`ThemeMode` choose. It registers both extensions
(`lib/api/theme/library_theme.dart:198`) and tints the few Material surfaces the
app shows from the same tokens (`lib/api/theme/library_theme.dart:168-197`):

| Surface | Token |
|---------|-------|
| Scaffold, canvas | `paper` |
| Dividers | `border` |
| Icons | `muted` |
| Text selection, cursor | `selection`, `accent` |
| Tooltips | `ink` on `paper` |
| Menu surfaces | `panel`, bordered with `border` |

`ColorScheme.fromSeed` is seeded from the accent with `primary`, `surface` and
`onSurface` pinned to palette values
(`lib/api/theme/library_theme.dart:176-182`), so no Material default leaks a
colour the theme did not choose.

## Where the page's styles come from

There is no markdown style sheet any more. The reader renders documents
itself, so the styles the page is set with are assembled by
[Reading Theme](14-reading-theme.md), which reads `context.palette` and
`context.type` — the two extensions above — and takes its sizes from the
[reading scale](../04-presentation/07-reading-scale.md)
(`lib/api/render/reading_theme.dart:58-162`). The division of labour:

| Decided by | What |
|------------|------|
| The theme (presentation) | Colours and typeface families |
| The reading scale (presentation) | Body size, measure, and the sizes cut from them |
| `ReadingTheme` (API) | Concrete `TextStyle`s, column widths, and the beat |
| `DocumentView` (API) | Where each block goes |

Code *colouring* is not part of a theme at all — syntax highlighting, diagrams
and images are a separate scope, listed in the
[Backlog](../07-roadmap/02-backlog.md).
