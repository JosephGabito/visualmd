# ThemePalette

## Purpose and boundary

`ThemePalette` is the whole colour surface of a theme: nine tokens named for
what they *mean*, never for the widget that happens to use them
(`lib/presentation/theme/theme_palette.dart`). A theme author decides
once what paper, ink and accent are; every widget follows.

That naming rule is the boundary. A token called `shelfRowHoverColor` would
tie the contract to today's layout and need to change with the shelf;
`accentSoft` remains meaningful wherever a quiet accent surface is needed.
This class does not own how a token reaches a widget — see
[Theme Binding](../05-api/06-theme.md) — or the values chosen for the shipped
palettes, which are recorded in [Built-in Themes](06-built-in-themes.md).

## Present wiring

Every token carries the doc comment that defines it
(`lib/presentation/theme/theme_palette.dart`):

| Token | Meaning | Required |
|-------|---------|----------|
| `paper` | The page. | yes |
| `panel` | Side panels and table heads: a shade off the paper. | yes |
| `border` | Hairlines between panes, around code and tables. | yes |
| `ink` | Body text. | yes |
| `muted` | Breadcrumbs, counts, inactive outline entries. | yes |
| `accent` | Links, active outline entry, bullets, selected shelf row. | yes |
| `codeBackground` | Behind fenced code blocks. | yes |
| `accentSoft` | Selected and hovered rows. | derived |
| `selection` | Text selection highlight. | derived |

The seven required names are listed once and checked before construction
(`lib/presentation/theme/theme_palette.dart`).

The two derived tokens are computed when a document omits them
(`lib/presentation/theme/theme_palette.dart`):

- `accentSoft` — the accent at 20 % alpha blended over the paper, so it reads
  as "selected" without fighting the text
  (`lib/presentation/theme/theme_palette.dart`).
- `selection` — the accent at 30 % alpha
  (`lib/presentation/theme/theme_palette.dart`).

`contrastRatio(foreground, background)` measures the actual colour pair with
WCAG relative luminance arithmetic, and `minimumTextContrast` records the
4.5:1 threshold used by the built-in-theme guard
(`lib/presentation/theme/theme_palette.dart`,
`lib/presentation/theme/theme_palette.dart`).

A theme that sets them explicitly overrides the derivation. The two house
themes use that option to tune those surfaces for their complete palettes.

## Inputs and outputs

In: a JSON object of token name to colour string. Colours accept `#rgb`,
`#rrggbb` and `#rrggbbaa`, with or without the leading `#`
(`lib/presentation/theme/theme_palette.dart`) — a three-digit value is
doubled, a six-digit one gets full alpha, and anything else is rejected.

Out: a `ThemePalette` of `dart:ui` `Color` values, or a
`ThemeFormatException`. `toJson` writes every token back
(`lib/presentation/theme/theme_palette.dart`) using `hex`, which omits
the alpha pair when a colour is fully opaque
(`lib/presentation/theme/theme_palette.dart`).

## Events

None today. Colours are values. When the
[plugin architecture](../07-roadmap/01-plugin-architecture.md) lands, a
palette is part of a contributed theme, not something that reacts.

## Lifecycle

Immutable, constructed once per theme — at compile time for built-ins
(`lib/presentation/theme/built_in_themes.dart`), at startup for user
themes. Copied into the widget tree's `LibraryPalette` when a theme is
applied, and otherwise untouched.

## Failure and recovery

Two failures, both naming the token
(`lib/presentation/theme/theme_palette.dart`):

| Problem | Message |
|---------|---------|
| A required token is absent or not a string | `palette."<key>" is required` |
| A token is present but unparseable | `palette."<key>" is not a hex colour: "…"` |

Either aborts the whole theme, not just the token: a palette missing its `ink`
has no sensible default, and guessing would ship an unreadable page. The
[registry](05-theme-registry.md) turns the exception into a skipped file.

## Transition

Nine tokens is deliberately few. New tokens should arrive derived-by-default,
so existing files stay valid — that is the pattern `accentSoft` and
`selection` set. Syntax highlighting would need its own colour tokens, but it
remains a separate scope; see the
[Backlog](../07-roadmap/02-backlog.md).
