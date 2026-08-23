# Reading Scale

## Purpose and boundary

`ReadingScale` holds the proportions of the reading column: one body size, one
leading, one measure, and every other size and gap derived from them
(`lib/presentation/theme/reading_scale.dart:8-34`). It is the typographic
half of the design, as [ThemePalette](02-theme-palette.md) is the colour half.

It owns proportions, not rendering: it knows nothing of `TextStyle`, any
renderer or Flutter, which is why the numbers can be reasoned about and tested
on their own. Turning them into a style sheet is
[Theme Binding](../05-api/06-theme.md); measuring a real face against them is
[Reading Pane](../05-api/04-reading-pane.md). A theme changes the *voice*
([ThemeTypefaces](03-theme-typefaces.md)); this changes the *rhythm*, and the
reader changes it, not the theme.

## Present wiring

The numbers were measured, not chosen by eye. At 18 px Literata the mean
character advance is 8.78 px, so the fixed 760 px column this replaced was
setting **87 characters** to the line (`test/typography_measure_test.dart`).

**The measure** is the number of characters on a line
(`lib/presentation/theme/reading_scale.dart:15-24`) and the first decision,
because it decides how reliably the eye finds the start of the next line.
Dyson and Kipping's screen study found 55-character lines easiest to read and
its 25-character condition slower; WCAG lets a reader limit lines to no more
than 80. The default target is 66, with 55 encoded as the lower comfortable
measure. These are different claims: 55 is the study's preference result, not
a universal threshold at which comprehension fails.

**The leading is a fallback now, not the value used.** `leading` is 1.65
(`lib/presentation/theme/reading_scale.dart:29-34`), but a measured face supplies
its own, derived from its cap height, descender and x-height by
[Font Metrics](../05-api/16-font-metrics.md).

**The gaps live elsewhere.** The scale deliberately does not declare them: the
page is spent in beats measured from the size *actually set*, which this
framework-free class cannot know because it does not know the face
(`lib/presentation/theme/reading_scale.dart:86-90`). The arithmetic is
[Reading Theme](../05-api/14-reading-theme.md), the rule
[Vertical Rhythm](11-vertical-rhythm.md).

**Heading sizes are ratios of the body**, not absolute values
(`lib/presentation/theme/reading_scale.dart:74-79`): `[2.05, 1.72, 1.44,
1.27, 1.11, 1.0]`, each level 11–19 % larger than the one below — enough to
see, never a leap. The last entry is `1.0`, and that is the point: **no
heading may be smaller than the text it heads**. At body size a `h6` leans on
weight and tracking instead (`lib/api/render/reading_theme.dart:105-127`).

Code sits a touch under the body at 0.94, and only a touch: the old reason for
shrinking it — a mono face reads larger at the same nominal size — is handled
by matching x-heights now, leaving only the wish that a code run should not
shout over the sentence carrying it
(`lib/presentation/theme/reading_scale.dart:92-97`). Table text is smaller
again, so a table stays a table
(`lib/presentation/theme/reading_scale.dart:99-100`).

### How one paragraph is told from the next

`ParagraphMarking` offers the two ways a page has ever done this, and they are
**alternatives, not companions** (`:126-139`):

| Marking | What the page does | Convention |
|---------|--------------------|------------|
| `spaced` | A gap between paragraphs, no indent | The screen's (`lib/presentation/theme/reading_scale.dart:132-134`) |
| `indented` | An indented first line, no gap | The book's — wastes no vertical room and keeps a column solid (`lib/presentation/theme/reading_scale.dart:136-139`) |

A space and an indent are the same signal said twice
(`lib/presentation/theme/reading_scale.dart:126-131`). The scale carries the
choice (`:26-27`); enforcing that only one appears is `ParagraphRules` in
[Document View](../05-api/12-document-view.md). The indent is **one em** — the
traditional quad, a multiple of the type rather than a fixed distance
(`lib/presentation/theme/reading_scale.dart:81-84`).

## Inputs and outputs

| In | Type | Default |
|----|------|---------|
| `base` | `double` | 18 px |
| `leading` | `double` | 1.65 |
| `measure` | `double` | 66 characters |
| `marking` | `ParagraphMarking` | `spaced` |

Out: `heading(level)`, `indent`, `code`, `tableText` — all derived — plus the
55-character `minimumReadableMeasure` used when a component has to protect a
text column.
`ReadingScale.comfortable` is the default
(`lib/presentation/theme/reading_scale.dart:36`).

The reader chooses `base` from eight fixed sizes
(`lib/presentation/theme/reading_scale.dart:38-41`); `larger()` and
`smaller()` step through them and stop at the ends
(`lib/presentation/theme/reading_scale.dart:43-54`).
`storedBase`/`fromStoredBase` are the round trip through a saved preference
(`lib/presentation/theme/reading_scale.dart:56-64`);
`storedMarking`/`markingFromStored` do the same for the paragraph choice
(`lib/presentation/theme/reading_scale.dart:66-72`).

## Events

None today. A scale is data. Under the
[plugin architecture](../07-roadmap/01-plugin-architecture.md) a theme
carrying its own proportions would extend the theme contract, and would still
be data — never code.

## Lifecycle

Immutable and cheap. `ReaderController` holds the current one and replaces it
whole when the reader changes size or marking
(`lib/api/reader_controller.dart:35-76`, `:162-179`). Value equality means an
unchanged choice does not rebuild
(`lib/presentation/theme/reading_scale.dart:102-123`).

## Failure and recovery

A stored size that will not parse, or one no longer offered, falls back to the
comfortable default rather than refusing to open
(`lib/presentation/theme/reading_scale.dart:56-61`). An unrecognised paragraph
marking falls back to `spaced` the same way, through a `switch` whose default
arm catches anything unfamiliar
(`lib/presentation/theme/reading_scale.dart:66-70`). `heading(level)` clamps
its argument to 1–6 (`lib/presentation/theme/reading_scale.dart:74-79`), so a
malformed level cannot index off the end.

The proportions are held by
`test/presentation/reading_scale_test.dart:19-63`: no heading smaller than
body, every step visible but not a leap, and the whole scale keeping its
ratios at any base size.

## Transition

`measure` is fixed today while `base` and `marking` move. It is a plausible
reader setting — a narrower measure suits a small window — and is already a
parameter rather than a constant, so adding a control is wiring rather than
redesign. The indent is not adjustable either: one em is the traditional value.
