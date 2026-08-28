# Built-in Themes

## Purpose and boundary

`BuiltInThemes` is the set of themes the reader ships with
(`lib/presentation/theme/built_in_themes.dart`). It keeps the menu useful before
a reader adds any files, gives the registry a dependable fallback, and makes
every shipped palette obey the same contract as a theme document.

The two house themes and Nord stay directly in `BuiltInThemes`. The larger
Codex-inspired collection lives in `CodexThemeCollection`
(`lib/presentation/theme/codex_theme_collection.dart`), while `ThemeFamily`
records which light and dark members belong under one menu name
(`lib/presentation/theme/theme_family.dart`). These objects own palette values
and pairings. They do not own loading precedence or menu rendering.

## Present wiring

The reader ships 34 `ReaderTheme` values: Paper, Lamplight, Nord, and 31 members
of 16 named families. Fifteen families have a light and dark member. Proof has
only the light palette supplied by the source collection, so Visual MD does not
invent a dark counterpart.

| Menu name | Light member | Dark member |
|-----------|--------------|-------------|
| Absolutely | `absolutely-light` | `absolutely-dark` |
| Catppuccin | `catppuccin-latte` | `catppuccin-mocha` |
| Codex | `codex-light` | `codex-dark` |
| Everforest | `everforest-light` | `everforest-dark` |
| GitHub | `github-light` | `github-dark` |
| Gruvbox | `gruvbox-light` | `gruvbox-dark` |
| Linear | `linear-light` | `linear-dark` |
| Notion | `notion-light` | `notion-dark` |
| One | `one-light` | `one-dark` |
| Proof | `proof-light` | — |
| Raycast | `raycast-light` | `raycast-dark` |
| Rose Pine | `rose-pine-dawn` | `rose-pine-moon` |
| Solarized | `solarized-light` | `solarized-dark` |
| Vercel | `vercel-light` | `vercel-dark` |
| VS Code Plus | `vscode-plus-light` | `vscode-plus-dark` |
| Xcode | `xcode-light` | `xcode-dark` |

Choosing a paired family creates a `FollowSystem` choice containing those two
ids. The row's swatch changes with system brightness, but the family remains
one choice. Proof appears only while the system is light and creates a fixed
choice. Paper, Lamplight, Nord, and custom themes remain individual rows in the
picker's Light and Dark sections (`lib/api/widgets/theme_picker.dart`).

Paper and Lamplight remain the defaults of their brightness. They form
`systemPair` and receive every missing-theme fallback, so adding this collection
does not alter an existing reader's preference.

## Inputs and outputs

There are no runtime inputs. All palettes and family records are constants.
`BuiltInThemes.all` supplies the registry, `BuiltInThemes.families` supplies the
family rows, and `BuiltInThemes.familyThemeIds` lets the picker avoid repeating
family members as individual themes (`lib/presentation/theme/built_in_themes.dart`).

The house themes remain the reference values for a custom palette:

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
| `selection` | `#A65A2E` at 25% | `#DFA273` at 30% |

### Adapting a palette to a reader

Visual MD maps familiar light and dark palette identities into nine semantic
reader tokens rather than importing a product stylesheet or editor syntax
rules. Backgrounds, foregrounds, and characteristic hues establish each
identity. Muted text and accent values move where the reference hue would fall
below the reader's 4.5:1 text-contrast floor on paper or panel
(`lib/presentation/theme/codex_theme_collection.dart`).

Every member keeps Visual MD's serif, sans, and mono families, x-height
normalization, measure, leading, and vertical rhythm. A theme changes the
atmosphere around a document, not the typographic rules that make it readable.

Nord and several family identities come from published theme systems. The
mapping into Visual MD's semantic tokens is project-specific:

| Palette | Published source |
|---------|------------------|
| Catppuccin | `https://github.com/catppuccin/palette` |
| Everforest | `https://github.com/sainnhe/everforest` |
| Gruvbox | `https://github.com/morhetz/gruvbox` |
| Nord | `https://www.nordtheme.com` |
| Rosé Pine | `https://github.com/rose-pine/rose-pine-theme` |
| Solarized | `https://ethanschoonover.com/solarized/` |

Their copyright notices and licence references are preserved in
`THIRD_PARTY_NOTICES.md`.

The remaining family names identify Visual MD's own reader-specific
interpretations of familiar product or editor moods. They are not imported
theme files and do not imply affiliation or endorsement.

## Events

None. These are immutable contributions. Choosing one is handled by the reader
controller in the same way as choosing a custom theme.

## Lifecycle

The constants live for the process lifetime and are never reloaded. Every
built-in round-trips through the public JSON format. Tests also assert that all
family members exist at their promised brightness and that every ink, muted,
and accent use reaches 4.5:1 contrast on its relevant surface
(`test/presentation/theme_test.dart`).

## Failure and recovery

A malformed constant fails during development. A family cannot name an absent
member without failing its registry test. At runtime, an old fixed choice for a
family member remains recognized and selected; a missing id still falls back to
Paper or Lamplight through the registry.

## Transition

The family type deliberately describes only pairing and display. Search,
favourites, or user-authored family metadata would need a product reason and a
public file-format decision rather than more fields added speculatively.
