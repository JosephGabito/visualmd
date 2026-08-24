# Built-in Themes

## Purpose and boundary

`BuiltInThemes` is the set of themes the reader ships with, written as Dart
constants (`lib/presentation/theme/built_in_themes.dart`). It exists so
the theme menu is never empty, so
[ThemeRegistry](05-theme-registry.md) always has something to fall back to,
and so every shipped theme is a worked example of the same contract a user
file must satisfy.

It owns the values and the choice of defaults. It does not own precedence — a
user theme with the same id replaces one of these, and the registry decides
that.

## Present wiring

Six themes, in menu order (`lib/presentation/theme/built_in_themes.dart`):

| id | Name | Brightness | Source |
|----|------|------------|--------|
| `paper` | Paper | light | House (`lib/presentation/theme/built_in_themes.dart`) |
| `lamplight` | Lamplight | dark | House (`lib/presentation/theme/built_in_themes.dart`) |
| `catppuccin-latte` | Catppuccin Latte | light | Catppuccin (`lib/presentation/theme/built_in_themes.dart`) |
| `catppuccin-mocha` | Catppuccin Mocha | dark | Catppuccin (`lib/presentation/theme/built_in_themes.dart`) |
| `nord` | Nord | dark | Nord (`lib/presentation/theme/built_in_themes.dart`) |
| `gruvbox-dark` | Gruvbox Dark | dark | Gruvbox (`lib/presentation/theme/built_in_themes.dart`) |

Paper and Lamplight are the defaults of their brightness
(`lib/presentation/theme/built_in_themes.dart`), which makes them the
two halves of `systemPair` and the destination of every fallback.

## Inputs and outputs

No inputs: these are `const` values, resolved at compile time. Out: a
`List<ReaderTheme>` as `all`, and the two named defaults.

The house themes in full — the reference values a new theme can be measured
against (`lib/presentation/theme/built_in_themes.dart`,
`lib/presentation/theme/built_in_themes.dart`):

| Token | Paper | Lamplight |
|-------|-------|-----------|
| `paper` | `#F8F4EB` | `#1E1B16` |
| `panel` | `#F0EADD` | `#24201A` |
| `border` | `#E2DAC7` | `#38312A` |
| `ink` | `#2B2925` | `#E9E1D0` |
| `muted` | `#70695C` | `#9F9685` |
| `accent` | `#A65A2E` | `#DFA273` |
| `codeBackground` | `#EDE6D4` | `#2A241D` |
| `accentSoft` | `#F1E2D3` | `#3A2D22` |
| `selection` | `#A65A2E` at 25 % | `#DFA273` at 30 % |

Both set `accentSoft` and `selection` explicitly rather than taking the
derived values, because a hand-picked wash reads better than a computed one.

### Attribution

Three of the six borrow published palettes, each MIT-licensed, credited in
the source beside the theme that uses it:

| Palette | Licence | Source |
|---------|---------|--------|
| Catppuccin | MIT | `https://github.com/catppuccin/palette` (`lib/presentation/theme/built_in_themes.dart`) |
| Nord | MIT | `https://www.nordtheme.com` (`lib/presentation/theme/built_in_themes.dart`) |
| Gruvbox | MIT | `https://github.com/morhetz/gruvbox` (`lib/presentation/theme/built_in_themes.dart`) |

The mapping from each published palette to Visual MD's nine semantic tokens is
project-specific; the source colour values are the attributed material.

## Events

None today. These are constants. Under the
[plugin architecture](../07-roadmap/01-plugin-architecture.md) they are simply
the contributions that ship in the box.

## Lifecycle

Compile-time constants, alive for the life of the process, never reloaded.
Every one is checked against the JSON format by a round-trip test, and every
text token is checked at 4.5:1 or better against the paper and panel surfaces
on which it is used (`test/presentation/theme_test.dart`). A built-in
therefore cannot drift into an unreadable pairing or a shape a user file could
not also express.

## Failure and recovery

None at runtime — a malformed built-in would not compile. Contrast is a
measured invariant for shipped palettes; user theme documents are still
format-checked rather than rejected for an author's colour choice.

## Transition

More themes are cheap and the list is the only thing that changes when one is
added. If the set grows much past a dozen, the picker needs grouping or
search before the menu does — see the
[Theme Picker](../05-api/07-theme-picker.md).
