# Vertical Rhythm

## Purpose and boundary

Vertical rhythm is the rule that decides every gap down the page. It is stated
here because it is a typographic principle rather than a widget, and applied in
the API ring where the sizes a face actually sets are known —
[Reading Theme](../05-api/14-reading-theme.md) holds the arithmetic
(`lib/api/render/reading_theme.dart:245-306`) and
[Document View](../05-api/12-document-view.md) spends it.

The rule is Bringhurst's, from *The Elements of Typographic Style*: the
vertical space taken by any departure from the running text must come to a
whole number of body lines, so the text returns afterwards **on the beat and in
phase**. A page where every line lands on the same rhythm is quieter to read
than one where each block drifts by a fraction of a line.

This owns spacing only. It does not own the measure or the type sizes — those
are [Reading Scale](07-reading-scale.md) — and it does not own the face, whose
metrics decide how tall a beat is in the first place
([Font Metrics](../05-api/16-font-metrics.md)).

## Present wiring

**The beat** is one line of body text: the rendered body size multiplied by the
leading (`lib/api/render/reading_theme.dart:245-253`). It is measured from
`renderedBase`, the size actually set after the face's x-height and the active
accessibility scaler have been accounted for
(`lib/api/render/reading_theme.dart:30-33`,
`lib/api/render/reading_theme.dart:80-81`). An earlier implementation counted
the grid from the requested size instead of the rendered size. Recording that
distinction here prevents the same drift when another face or scaler is
introduced.

Four things must come to whole beats for the rule to hold:

| What | How | Citation |
|------|-----|----------|
| The gap between blocks | Exactly one beat — a blank line | `lib/api/render/reading_theme.dart:280-281` |
| Space above a heading | Whole beats only: `h2` and `h3` take one extra, the rest none | `lib/api/render/reading_theme.dart:283-292` |
| A heading's own line box | Rounded up to the next whole beat after scaling, however large it is set | `lib/api/render/reading_theme.dart:105-127` |
| A code block | One beat per line of code, half a beat of padding above and below | `lib/api/render/reading_theme.dart:137-146`, `lib/api/render/reading_theme.dart:259-262`, `lib/api/render/document_view.dart:207-213` |
| A horizontal rule | Its complete box is one beat | `lib/api/render/document_view.dart:245-255` |

A heading takes fewer extra beats than the eye expects, because its own box was
rounded up too and carries some of that space inside it
(`lib/api/render/reading_theme.dart:280-292`). A heading directly following
another heading takes the plain beat and no extra: there is no running text
between them to be separated from, and a section title with its first
subheading should read as one unit
(`lib/api/render/reading_theme.dart:294-306`).

**The strut is what makes the grid real.** Without it a line carrying an inline
code span — set smaller than the prose around it — grows to fit and pushes
itself off the beat, and the grid becomes something the page merely aspires to.
`strutFor` gives every paragraph and heading a fixed line box with
`forceStrutHeight` (`lib/api/render/reading_theme.dart:270-275`), applied in
[Document View](../05-api/12-document-view.md)
(`lib/api/render/document_view.dart:188`, `:199`).

Two knock-on decisions follow from the rule rather than from taste. A code
block has no border, because its own ground already says what it is and a
border is both a second signal and a height that breaks the grid
(`lib/api/render/document_view.dart:214-219`). A tight list has no space
between its items at all, so its lines follow one another exactly as the lines
of a paragraph do; a loose one gets a whole beat
(`lib/api/render/document_view.dart:329-333`).

## Inputs and outputs

In: the rendered body size and the leading for the face in hand.

Out: `baseline` (the beat), `snap(height)` rounding up to the next whole one,
`blockGap`, `spaceAbove(level)` and `gapBefore(headingLevel:, afterHeading:)`
(`lib/api/render/reading_theme.dart:245-306`).

## Events

None today. The rhythm is arithmetic over the theme in hand. Under the
[plugin architecture](../07-roadmap/01-plugin-architecture.md) a contributor
rendering a new kind of block would have to spend whole beats like everything
else — the obligation belongs to the block, not to the grid.

## Lifecycle

Derived with the rest of the theme and rebuilt whenever the palette, the face
or the scale changes. Nothing is cached and nothing is stateful.

## Failure and recovery

Nothing throws: every member is arithmetic, and `spaceAbove` clamps its level
to 1–6 (`lib/api/render/reading_theme.dart:283-292`).

The invariant is a test rather than an intention.
`test/presentation/document_view_test.dart:95-165` renders headings, code, a
rule and a tight list between paragraphs, then asserts
every paragraph's offset is a whole number of beats — reporting the fractional
part when it is not. It caught three separate sources of drift in turn: the
beat measured in the wrong unit, unsnapped heading boxes, and a code block
whose padding and border did not add up.

## Transition

**Tables are knowingly off the beat.** Their height is content-driven, and
nothing rounds it. Bringhurst's rule permits a departure so long as the text
returns in phase afterwards, which it does not here — this is a real remaining
gap rather than a licensed exception.

The heading leading that gets rounded — 1.18 above `h2`, 1.3 below
(`lib/api/render/reading_theme.dart:119`) — is a judgement, and the number to
revisit if headings ever feel loose inside their boxes. Flutter distributes a
line box's extra leading evenly above and below the text, so some of the space
meant to sit above a heading appears below it; controlling that would need
per-line placement the text engine does not expose.
