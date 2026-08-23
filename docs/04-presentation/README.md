# Presentation

This shelf describes the visual language of Visual MD: themes, typefaces,
reading proportions, and the small typographic details that make a page easier
to follow. It answers *what the page should mean* without deciding how Flutter
draws it.

That separation keeps visual choices approachable. A theme is plain data, so
it can be read from JSON, tested without a widget tree, and rendered in more
than one environment. The [API](../05-api/README.md) ring turns that data into
the page a reader sees.

| Document | What it covers |
|----------|----------------|
| [ReaderTheme](01-reader-theme.md) | The theme contract and its JSON document format |
| [ThemePalette](02-theme-palette.md) | The nine semantic colour tokens, required and derived |
| [ThemeTypefaces](03-theme-typefaces.md) | The three voices of the page and their fallback |
| [ThemeChoice](04-theme-choice.md) | One theme, or a light/dark pair that follows the system |
| [ThemeRegistry](05-theme-registry.md) | Every theme available, and what happens to a bad file |
| [Built-in Themes](06-built-in-themes.md) | The six shipped themes, with values and attribution |
| [Reading Scale](07-reading-scale.md) | The measure, the leading, and every gap cut from the line |
| [Hanging Punctuation](08-hanging-punctuation.md) | Which marks hang outside the column, and how far |
| [Widow Binding](09-widow-binding.md) | Keeping the last word of a paragraph off a line of its own |
| [Sources](10-sources.md) | Where these decisions came from, and what the research actually says |
| [Vertical Rhythm](11-vertical-rhythm.md) | The beat every gap is spent in, and the rule that keeps text in phase |

## How it fits

The presentation ring uses only Dart libraries and its own files. `dart:ui`
provides `Color` and `Brightness`, while `dart:convert` is enough to understand
a theme document (`lib/presentation/theme/theme_palette.dart:1`,
`lib/presentation/theme/reader_theme.dart:1`,
`lib/presentation/theme/theme_registry.dart:1`). It does not need Flutter or a
package dependency.

Work that needs a widget, a document, or the file system happens in the ring
that owns that concern. For example, `ReaderFiles` locates theme files and
passes their text inward; the presentation ring only parses the text
(`lib/infrastructure/io/reader_files.dart:9-67`). The architecture test keeps
that boundary visible as the project grows
(`test/architecture/dependency_rules_test.dart:21-24`,
`test/architecture/dependency_rules_test.dart:30`).

## A useful reading path

For the shortest tour, begin with [ReaderTheme](01-reader-theme.md), then
[ThemePalette](02-theme-palette.md). The next few documents unpack the same
theme contract, and [Built-in Themes](06-built-in-themes.md) provides complete
examples.

[Reading Scale](07-reading-scale.md) is the other half of the design: a theme
chooses the voice, the scale gives the page its rhythm, and the reader chooses
the size. [Hanging Punctuation](08-hanging-punctuation.md) and
[Widow Binding](09-widow-binding.md) are focused examples of the split between
meaning and rendering. They describe the typographic choice; the
[Paragraph](../05-api/15-paragraph.md) widget applies it with Flutter's text
engine.

Component documents follow the
[Component Document Template](../00-foundation/05-component-document-template.md).
Related: the [API](../05-api/README.md) ring renders this visual language,
[Creating a Theme](../09-contributing/05-creating-a-theme.md) is the practical
guide for theme authors, and
[Dependency Direction](../00-foundation/03-dependency-direction.md) explains
why this ring exists.
