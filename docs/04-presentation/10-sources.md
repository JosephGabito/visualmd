# Sources

The reading decisions in this shelf have traceable sources. This document
records both the evidence that shaped the page and the places where Visual MD
made a project-specific choice, so either can be reviewed independently.

## Books

**Ellen Lupton, *Thinking with Type*, 2nd edition** — the source for how this
reader marks structure.

| What it settled | Where |
|---|---|
| An elegant economy of signals: no more than three cues per level, and emphasis needs only one | *Hierarchy* |
| Italic is the standard mark of emphasis — which is also why a quotation is not set in it | *Hierarchy* |
| Indents and paragraph spacing are alternatives; using both is the mark of an overloaded page | *Marking paragraphs* |
| Never indent the opening line of a body of text — an indent signals a break, and nothing has been broken from yet | *Marking paragraphs* |
| Hanging punctuation keeps opening marks from carving a notch out of the left edge | *Punctuation*, p. 58 |
| Old-style figures sit in the line; lining figures stand up out of it | *Numerals* |
| Light type on a dark ground reads better tracked a little looser | *Tracking*, p. 56 |
| A good rag is pleasantly uneven, with hyphenation kept to a minimum | *Alignment* |
| A baseline grid aligns text across a field | *Grid*, p. 198 |

Lupton's paragraph specimens on p. 126 warn that a full blank line is often
too open and show a half-line alternative. Visual MD's **spaced** mode therefore
uses half a beat after consecutive paragraphs. Its **indented** mode uses the
book's one-em first-line indent and no gap; the opening paragraph stays flush.
Both are pair-aware outcomes of `spaceAfter`, never combined signals.

**Robert Bringhurst, *The Elements of Typographic Style*** — the source for
the vertical rhythm.

The rule taken from it is that the vertical space consumed by any departure
from the running text should be an even multiple of the basic leading, so the
main text returns after each variation on the beat and in phase. Everything on
this page is spent in whole beats because of it — see
[Vertical Rhythm](11-vertical-rhythm.md).

## Legibility research

Summarised in the overview at [legible-typography.com](https://legible-typography.com/en/5-overview-of-research-type),
and consistent across the studies it collects.

- **Serif against sans is a dead end.** Lund's review of 72 studies found no
  valid conclusion in favour of either. The family of the face is not the
  lever it is assumed to be.
- **X-height, not nominal size, decides how large text reads.** This is why a
  size in this reader is a size of letters, worked out per face — see
  [Font Metrics](../05-api/16-font-metrics.md) and
  `lib/api/theme/font_metrics.dart`. Measuring it caught a real defect:
  body text was rendering about 7 % smaller than the sans beside it at the
  same nominal size.
- **Letter differentiation matters, and old-style faces can be worse at it.**
  In one study Garamond's `e` was identified correctly a tenth as often as
  Verdana's. For documents full of identifiers, that argues against the
  bookish face and for one drawn for screens.
- **Italic slows continuous reading; bold does not.** Both are kept for
  emphasis and headings rather than for passages.
- **Capitals slow reading.** They appear only on short chrome labels, never
  in a document.
- **Making text harder to read does not aid memory.** The disfluency effect
  behind fonts such as Sans Forgetica did not survive a meta-analysis of
  seventeen studies.

The overarching finding put the choice of face in perspective:
typeface choice matters far less than designers assume, *provided the face is
conventional and drawn for its medium*. That keeps the larger investment on
measure, leading, rhythm, and character differentiation rather than treating a
font swap as the main source of clarity.

**Dyson and Kipping, “The Effects of Line Length and Method of Movement on
Patterns of Reading from Screen” (1998)** tested 25-, 55- and 100-character
lines. The 100-character condition was read faster than the 25-character one,
comprehension stayed constant, and readers judged 55 characters easiest. The
reader therefore uses 55 as its lower comfortable measure, not as a claimed
comprehension cliff, while its 66-character target remains inside the familiar
middle band. [Read the paper](https://journals.uc.edu/index.php/vl/article/view/5671).

The reader now sets its page in **Alegreya**, drawn by Huerta Tipográfica for
literature and long-form text. Literata — drawn for long reading on screens,
across rendering technologies, with a real optical-size axis — remains bundled
and selectable. See [Theme Binding](../05-api/06-theme.md).

## Heading rhythm

[Butterick](https://practicaltypography.com/headings.html) treats headings as
signposts: prefer subtle space, bold rather than italic, and the smallest size
change that makes the hierarchy visible. Production reading systems confirm
that display leading tightens as type grows. [NICE](https://design-system.nice.org.uk/foundations/typography/)
uses 1.2 for `h1`/`h2`, opening toward 1.6 at body-sized `h6`; the tested
[GOV.UK scale](https://design-system.service.gov.uk/styles/type-scale/) is
tighter still at its largest sizes. Visual MD's `[1.14, 1.18, 1.24, 1.30,
1.40]` follows that progression, then uses measured body leading at `h6`
(`lib/api/render/reading_theme.dart`). The completed heading, not each
display line, is reconciled with the body grid. Flutter may therefore expand a
mixed-script line before the renderer measures it.

## Technical-document systems

[Geist Mono](https://github.com/vercel/geist-font) was designed for code
editors, diagrams, terminals and other interfaces where code is represented.
That is the medium Visual MD asks it to serve. Its bundled variable font is
licensed under the SIL Open Font License 1.1, and its measured x-height is
0.530 em. Visual MD normalises that metric before applying the code scale, so
the decision to set dense source three logical pixels below prose remains
independent of the face chosen. At the comfortable reading scale that is a
15 px face on a 22 px line, against prose at 18 px. The 13 px floor protects
punctuation when the reader chooses the smallest text setting. This absolute
scale expresses the project-specific hierarchy: paragraphs address the reader,
while code is a reference or example consulted from that prose.

[Primer](https://primer.style/product/primitives/typography/) sets inline code
at 0.9285 em so it inherits the role around it without shouting over the prose.
At Visual MD's comfortable 18 px scale that evidence lands close to a 17 px
inline face. The reader records that decision as an absolute one-logical-pixel
step from the surrounding role rather than retaining Primer's percentage.
The [CSS Text Decoration specification](https://www.w3.org/TR/css-text-decor-4/)
defines an underline as a line decoration painted with the text and treats any
leak beyond its box as ink overflow rather than layout overflow. Flutter's
[`decorationThickness`](https://api.flutter.dev/flutter/painting/TextStyle/decorationThickness.html)
is a multiplier of the face's own underline. Visual MD therefore normalises
the surrounding face to its measured letter size, subtracts one logical pixel,
normalises Geist Mono from that target, and adds a translucent muted underline
at 1.25 of the face's own stroke. It is a quiet technical signal that adds no
box, padding or height. The text takes the theme accent; where that falls below
WCAG's 4.5:1 threshold, it is mixed toward the theme's ink only until the
threshold is met. The run remains real text, so symbols, paths and commands all
select, copy and reflow as part of the sentence.

## Checklists

**Paul Fenton's ten commandments of typography** were used as an audit rather
than a source. Two failures they caught are fixed — widows were unhandled
(see [Widow Binding](09-widow-binding.md)), and headings mixed two bold
weights where one would do. One is knowingly unmet: the reader ships three
families, not two. The page itself is a pair — a serif for reading and a mono
for code, which is functional rather than a third voice — while Inter is
furniture, used for the shelf, the outline and the controls, and never inside
a document.

## Accessibility standards

WCAG 2.2 requires at least 4.5:1 contrast for ordinary text and asks reading
surfaces to tolerate text resizing without losing content. The built-in
palettes are measured against both paper and panel surfaces, and accessibility
scaling is included in the measure, baseline grid and hanging-punctuation
geometry rather than left to the final `Text` widget.

- [Contrast (Minimum), WCAG 2.2](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html)
- [Visual Presentation, WCAG 2.2](https://www.w3.org/WAI/WCAG22/Understanding/visual-presentation.html)
- [Resize Text, WCAG 2.1](https://www.w3.org/WAI/WCAG21/Understanding/resize-text.html)
- [Reflow, WCAG 2.2](https://www.w3.org/WAI/WCAG22/Understanding/reflow.html) —
  a data table may keep its two-dimensional layout in its own scrollable
  region, while its individual cells still reflow and the surrounding page
  must not acquire horizontal scrolling.
