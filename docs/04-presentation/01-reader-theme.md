# ReaderTheme

## Purpose and boundary

`ReaderTheme` is one theme: an identity, a brightness, a
[palette](02-theme-palette.md) and a set of
[typefaces](03-theme-typefaces.md). It owns the *contract* — what a theme
consists of and how a theme document is read — and nothing about rendering.
It lives in the presentation ring
(`lib/presentation/theme/reader_theme.dart:10-86`), so it holds `Color` and
`Brightness` from `dart:ui` and knows no widget.

It does not own: where theme files live (that is
[ReaderFiles](../03-infrastructure/desktop/05-reader-files.md)), which theme is
in use (that is [ThemeChoice](04-theme-choice.md)), what themes exist (that is
[ThemeRegistry](05-theme-registry.md)), or how a family name becomes a font
(that is [Theme Binding](../05-api/06-theme.md)).

## Present wiring

Five fields and an origin (`lib/presentation/theme/reader_theme.dart:13-20`):

| Field | Type | Meaning |
|-------|------|---------|
| `id` | `String` | Stable identity. Lowercase letters, digits, hyphens. |
| `name` | `String` | What the theme menu shows. |
| `brightness` | `Brightness` | Which half of a light/dark pair it can serve. |
| `palette` | `ThemePalette` | The nine colour tokens. |
| `typefaces` | `ThemeTypefaces` | Three family names; defaults to the library set. |
| `origin` | `String` | `built-in`, or the file it was read from. |

`isDark` is the one derived property
(`lib/presentation/theme/reader_theme.dart:31`), used to group themes in the
picker. `schemaVersion` is 1 (`lib/presentation/theme/reader_theme.dart:11`)
and is written into every `toJson`
(`lib/presentation/theme/reader_theme.dart:75-82`), so a future format change
can be recognised rather than guessed at.

## Inputs and outputs

In: a decoded JSON map and the origin it came from
(`lib/presentation/theme/reader_theme.dart:35`). The document format is the
class, field for field:

```json
{
  "schema": 1,
  "id": "sepia",
  "name": "Sepia",
  "brightness": "light",
  "palette": { "paper": "#f4ecd8", "ink": "#3b2f2f", "accent": "#8b4513" },
  "typefaces": { "serif": "Lora" }
}
```

Out: a `ReaderTheme`, or a `ThemeFormatException`. `toJson` round-trips, which
is how every built-in is tested against the file format
(`test/presentation/theme_test.dart:66-74`).

Constants are the other input: the built-ins are written as Dart
`const ReaderTheme(...)` (`lib/presentation/theme/built_in_themes.dart:9-24`),
the same shape without the parsing.

## Events

None today. A theme is data, so it announces nothing. When the
[plugin architecture](../07-roadmap/01-plugin-architecture.md) lands, themes
are contributors — values registered into an extension point — not reactors.

## Lifecycle

Immutable and effectively permanent. Built-ins are compile-time constants;
user themes are parsed once at startup by
[ThemeRegistry](05-theme-registry.md) and live as long as the process. There
is no reload: adding or editing a file takes effect on the next launch.

## Failure and recovery

Every rejection names the field and the reason
(`lib/presentation/theme/reader_theme.dart:36-61`):

| Problem | Message |
|---------|---------|
| Missing or blank `id`, `name`, `brightness` | `"<key>" must be a non-empty string` |
| `id` with capitals or spaces | `"id" must be lowercase letters, digits and hyphens: "…"` |
| `brightness` other than `light`/`dark` | `"brightness" must be "light" or "dark", not "…"` |
| `palette` not an object | `"palette" must be an object` |
| `typefaces` present but not an object | `"typefaces" must be an object when present` |

The exception carries only a `reason` string
(`lib/presentation/theme/theme_format_exception.dart:2-8`); the registry pairs
it with the file name and the reader keeps every other theme.

## Transition

The shape is meant to stay still — it is the published contract for
[Creating a Theme](../09-contributing/05-creating-a-theme.md). Additions
should be optional fields with derived defaults, the way `accentSoft` and
`selection` already are, so old files keep working. A breaking change means
`schemaVersion` 2 and reading both. Syntax colours for code, diagrams and
images are deliberately outside this contract; see the
[Backlog](../07-roadmap/02-backlog.md).
