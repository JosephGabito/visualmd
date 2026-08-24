# Reading Theme

## Purpose and boundary

`ReadingTheme` is every text style and gap the page is set with, derived once
from the palette, the faces and the
[Reading Scale](../04-presentation/07-reading-scale.md)
(`lib/api/render/reading_theme.dart`).

It is the reader's own vocabulary rather than a rendering package's, because
the distinctions that matter here are not ones a general-purpose style sheet
has (`lib/api/render/reading_theme.dart`): a width for prose and a wider
one for code, gaps expressed in lines rather than pixels, and figures that
differ between running text and tables.

It owns style values and the two column widths. It owns no layout — that is
[Document View](12-document-view.md) — and it defines no colours or faces of
its own; those come from the theme the reader picked, through
[Theme Binding](06-theme.md).

## Present wiring

`ReadingTheme.of(context, scale)` reads the palette, the typefaces, the
brightness and `MediaQuery.textScalerOf(context)`, then derives everything
(`lib/api/render/reading_theme.dart`). Accessibility scaling is part of
the page geometry, not an afterthought applied only when `Text` paints.

**The leading comes from the face, not from the scale.** It is derived from the
face's own cap height, descender and x-height by
[Font Metrics](16-font-metrics.md) (`lib/api/render/reading_theme.dart`), so
the rhythm follows the face rather than a constant
(`lib/api/render/reading_theme.dart`). `renderedBase` is the body size as
it is *actually set*, after x-height normalisation and accessibility scaling,
and the beat is measured
from that rather than from the size asked for — otherwise the grid is counted
in a unit the page never uses
(`lib/api/render/reading_theme.dart`, `lib/api/render/reading_theme.dart`).

**Two refinements that should never be noticed.** Light type on a dark ground
optically thickens and closes up, so a dark theme is tracked a hair looser —
0.008 of the body size (`lib/api/render/reading_theme.dart`). And prose
is set with old-style figures, which have ascenders and descenders like
lowercase letters, so a number in a sentence sits *in* the line rather than
standing up out of it; tables want the opposite, lining and tabular, so their
columns agree (`lib/api/render/reading_theme.dart`). Code is given a
slashed zero, because zero and capital O are the pair a reader of technical
documents most often has to tell apart
(`lib/api/render/reading_theme.dart`).

**Tone as a third cue, under size and weight.** The scale runs `h1` darkest,
down through the body, to `h5` and `h6` sitting just back from it — small
headings should recede rather than compete with the sentence beneath them
(`lib/api/render/reading_theme.dart`). Two things about how it is
written. It is a distance from the running text *towards ink* or *away from
it*, never a lightness: on a dark page "more emphatic" means lighter, and the
same numbers have to work both ways round
(`lib/api/render/reading_theme.dart`). And the body itself is never
dimmed — contrast is what legibility rests on, and a paragraph is the thing
being read (`lib/api/render/reading_theme.dart`). `h4` therefore sits
with the text rather than above it.

**Headings** use natural display leading: `[1.14, 1.18, 1.24, 1.30, 1.40]`
from `h1` through `h5`, then the face's measured body leading at `h6`. Display
lines close up as they grow and open gradually as they approach running text
(`lib/api/render/reading_theme.dart`). The line is deliberately not
snapped here; [Document View](12-document-view.md) reconciles the completed
shaped block, after fallback scripts and inline roles have established its real
height. Every level takes the same weight: size already says which level a
heading is, and a second, quieter bold would repeat the signal. Tracking
tightens as the size grows; at body size `h6` leans on a little extra tracking
instead (`lib/api/render/reading_theme.dart`).

**Quoting.** `ReadingTheme.quoting(theme)` returns the same page one shade
back, for matter inside a quotation
(`lib/api/render/reading_theme.dart`). The rule down its left already
says it is quoted; the colour is the second and last signal.

**Inline roles.** `linkFor(base)` preserves the complete surrounding style and
adds only link signals. `inlineCodeFor(base)` measures the surrounding face,
steps back one logical pixel, and normalises Geist Mono from that target, so
headings and tables retain their hierarchy without a hidden percentage
(`lib/api/render/reading_theme.dart`). Mono and its contrast-safe code colour
already identify the technical token; it has no underline because that mark is
reserved for content the reader can follow. The text uses the accent;
if that is below 4.5:1 against paper, `_contrastSafeAccent` finds the smallest
mix toward ink that meets the threshold.

**The two widths** (`lib/api/render/reading_theme.dart`):

- `proseWidth(available)` — the measure, or the room available if that is
  narrower. Everything on the page lines up against this, including the
  breadcrumb in the [reading pane](04-reading-pane.md).
- `wideWidth(available)` — up to 1.35 × prose, for code and tables. They are
  not bound by the measure, because a line of code is as long as it is, but
  they still belong to the same page.

**The rhythm.** Displayed departures return in whole beats; consecutive spaced
paragraphs use a half-beat and indented paragraphs use none. A strut holds every
line box to one so inline code cannot push it off the grid
(`lib/api/render/reading_theme.dart`); see [Vertical Rhythm](../04-presentation/11-vertical-rhythm.md).

## Inputs and outputs

| In | Type | From |
|----|------|------|
| `context` | `BuildContext` | For palette, typefaces, brightness and the active `TextScaler` |
| `scale` | `ReadingScale` | `ReaderController.readingScale` |

Out: `body`, `code`, `quote`, `marker`, `tableHead`, `tableBody`, `headings`
(`lib/api/render/reading_theme.dart`), the role-aware `linkFor` and
inline-code rules (`lib/api/render/reading_theme.dart`), `leading`,
`renderedBase`, rendered `em` and `indent`, the two widths, `strutFor`, and the
rhythm members `baseline`, `snap`, `blockGap` and the single external-spacing
contract `spaceAfter(current, next)` (`lib/api/render/reading_theme.dart`).

## Events

None today. It is derived state, rebuilt from the theme and the scale.

## Lifecycle

`@immutable` (`lib/api/render/reading_theme.dart`) and rebuilt whenever the
palette, the faces or the scale change — which is to say whenever the reader
changes theme or text size. Built in the [reading pane](04-reading-pane.md)
and handed down; nothing caches it.

## Failure and recovery

Nothing throws. `heading(level)` clamps its argument to 1–6
(`lib/api/render/reading_theme.dart`), so a malformed level renders as `h1`
or `h6` rather than crashing. Both widths clamp to the room available, so a very
narrow window gets a narrow column rather than an overflow. The compact shell
keeps side panels over that column instead of squeezing it.

## Transition

The tonal scale — `[0.26, 0.16, 0.07, 0.0]` towards ink and 0.22 away from it
(`lib/api/render/reading_theme.dart`) — is judged rather than measured,
and is the pair of numbers to revisit if the hierarchy ever reads too flat or
too stepped. The 1.35 wide-block factor is a judgement too. Per-theme
typography would enter here as a theme-owned `ReadingScale`.
