# ThemeTypefaces

## Purpose and boundary

`ThemeTypefaces` names the three voices of the page: a serif reading role, a
sans role shared by the furniture and optional Sans reading mode, and a mono
for code
(`lib/presentation/theme/theme_typefaces.dart`). It owns the *names*
only. Turning a name into glyphs happens in the API ring, where the font
layer lives — see [Theme Binding](../05-api/06-theme.md).

That division is why this class is three strings and no more. Sizes, weights
and line heights are not here either: they belong to the reading design, not
to the theme, so a theme changes the voice of the page without changing its
rhythm.

## Present wiring

| Field | Default | Used for |
|-------|---------|----------|
| `serif` | `Alegreya` | Reading text, headings, the app name. |
| `sans` | `Inter` | Shelf, outline, controls, and Sans reading mode. |
| `mono` | `Geist Mono` | Code, inline and block. |

`ThemeTypefaces.library` holds those three defaults
(`lib/presentation/theme/theme_typefaces.dart`). Alegreya reads the page:
a face drawn by Huerta Tipografica for literature and long-form text, with the
long extenders and the movement of a book rather than the even texture of a
screen serif. Geist Mono was drawn for code editors, diagrams and terminals,
so the functional voice is meant for dense source rather than borrowed from a
prose face. Literata is still bundled and still selectable — a theme may name
it, and `?serif=<family>` swaps the reading face for one run. It serves three
purposes at once: the default when a theme omits `typefaces` entirely
(`lib/presentation/theme/reader_theme.dart`), the per-field default when a
theme names only some of them
(`lib/presentation/theme/theme_typefaces.dart`), and the fallback when a
named family cannot be resolved at render time.

[ReadingMode](13-reading-mode.md) selects which proportional role sets document
content without changing the theme.

## Inputs and outputs

In: an optional JSON object with any of `serif`, `sans`, `mono`
(`lib/presentation/theme/theme_typefaces.dart`). Absent keys fall back
field by field, so `{"serif": "Lora"}` is a complete and valid declaration.

Out: three family names, or a `ThemeFormatException`. `toJson` always writes
all three (`lib/presentation/theme/theme_typefaces.dart`), so a
round-tripped theme is explicit about what it inherited.

The four shipped families are bundled and resolved without a network request.
Other names are requested through Google Fonts by the API ring; if a name
cannot be resolved, the matching library family is used instead
(`lib/api/theme/library_theme.dart`).

## Events

None today. Typeface names are values. Under the
[plugin architecture](../07-roadmap/01-plugin-architecture.md) they arrive as
part of a contributed theme, not as something that reacts.

## Lifecycle

Immutable, built once per theme and held for the life of the process. Read
each time a widget asks for a text style, through `context.type`.

## Failure and recovery

One failure at parse time: a key present but not a non-empty string
(`lib/presentation/theme/theme_typefaces.dart`), reported as
`typefaces."<key>" must be a non-empty string`, which skips the whole theme.

A *valid* name that names no real font is not a parse failure — it cannot be
detected here, because this ring has no font layer. It surfaces later as a
silent fallback to the library family
(`lib/api/theme/library_theme.dart`). The reader sees a different
face than the author intended; nothing breaks.

## Transition

Per-voice weight or size adjustments are plausible future additions. They
would remain optional fields with derived defaults so existing theme files
stay valid. The font files themselves are already bundled; the
[Theme Binding](../05-api/06-theme.md) guide explains how bundled and external
family names are resolved without changing this contract.
