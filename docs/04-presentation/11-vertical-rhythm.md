# Vertical Rhythm

## Purpose and boundary

Vertical rhythm is the rule that decides every gap down the page. It is stated
here because it is a typographic principle rather than a widget, and applied in
the API ring where the sizes a face actually sets are known —
[Reading Theme](../05-api/14-reading-theme.md) holds the arithmetic
(`lib/api/render/reading_theme.dart`) and
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
leading (`lib/api/render/reading_theme.dart`). It is measured from
`renderedBase`, the size actually set after the face's x-height and the active
accessibility scaler have been accounted for
(`lib/api/render/reading_theme.dart`,
`lib/api/render/reading_theme.dart`). An earlier implementation counted
the grid from the requested size instead of the rendered size. Recording that
distinction here prevents the same drift when another face or scaler is
introduced.

Five things establish the flow and return displayed departures to whole beats:

| What | How | Citation |
|------|-----|----------|
| External spacing | The preceding block alone owns `spaceAfter(current, next)`; no block adds space above itself | `lib/api/render/reading_theme.dart`, `lib/api/render/document_view.dart` |
| Body relationships | Ordinary blocks get one beat; consecutive spaced paragraphs get Lupton's quieter half-beat; indented paragraphs get no gap | `lib/api/render/reading_theme.dart` |
| A heading's own lines | Natural display leading: tight at `h1`, opening gradually toward the body at `h6` | `lib/api/render/reading_theme.dart` |
| The complete heading block | Its shaped height and outgoing half-beat are reconciled together; only the grid correction remains inside the heading | `lib/api/render/document_view.dart` |
| A code block | Compact source lines at 72 percent of a beat; the completed coloured surface rounds to the prose grid | `lib/api/render/reading_theme.dart`, `lib/api/widgets/code_block.dart` |
| A horizontal rule | Its complete box is one beat | `lib/api/render/document_view.dart` |

A heading is reconciled only after Flutter has shaped the complete block. Its
lines therefore stay close enough to read as one display phrase. The sequence
owns a half-beat after it; the heading accounts for that known outgoing space
and keeps only the remaining grid correction inside its own box. The combined
height still consumes whole beats, and the heading remains closer to what it
introduces (`lib/api/render/reading_theme.dart`,
`lib/api/render/document_view.dart`).

This is the **forward-owned spacing rule**: lay out a block, then spend the gap
it owns before laying out the next one. `spaceAfter(current, next)` sees the
pair because their relationship matters, but only `current` emits the result.
The final block returns zero. `_BlockSequence` applies the rule recursively,
so quotations and list items cannot acquire a competing top-margin convention
(`lib/api/render/reading_theme.dart`, `lib/api/render/document_view.dart`).
Paragraph spacing is the one half-beat interval inside running text; headings
account for their half-beat while reconciling their complete display box.

**The strut is what makes the running-text grid real.** Without it a paragraph
carrying an inline code span — set smaller than the prose around it — can grow
and push itself off the beat. `strutFor` fixes paragraph lines to the body box
(`lib/api/render/reading_theme.dart`), applied in
[Document View](../05-api/12-document-view.md)
(`lib/api/render/document_view.dart`). Headings intentionally opt out: their
complete shaped block is reconciled instead.

Two knock-on decisions follow from the rule rather than from taste. Code lines
must be allowed a denser texture than prose, so the completed body reconciles
its shaped height instead of forcing every source line onto the prose beat
(`lib/api/widgets/code_block.dart`). The block has no border, because its own
ground already says what it is and a border is both a second signal and a
height that breaks the grid (`lib/api/render/document_view.dart`). A tight list has no space
between its items at all, so its lines follow one another exactly as the lines
of a paragraph do; a loose one gets a whole beat
(`lib/api/render/document_view.dart`).

## Inputs and outputs

In: the rendered body size and the leading for the face in hand.

Out: `baseline` (the beat), `snap(height)` rounding up to the next whole one,
`blockGap` and the pair-aware `spaceAfter(current, next)`
(`lib/api/render/reading_theme.dart`).

## Events

None today. The rhythm is arithmetic over the theme in hand. Under the
[plugin architecture](../07-roadmap/01-plugin-architecture.md) a contributor
rendering a new kind of displayed block would have to return prose on the beat
like everything else — the obligation belongs to the block, not to the grid.

## Lifecycle

Derived with the rest of the theme and rebuilt whenever the palette, the face
or the scale changes. Nothing is cached and nothing is stateful.

## Failure and recovery

Nothing throws: every member is arithmetic, `heading(level)` clamps its level
to 1–6, and `spaceAfter` returns zero at the end of a sequence
(`lib/api/render/reading_theme.dart`).

The invariant is a test rather than an intention. The spacing suite states
that the current block owns the only external gap and proves the same rule is
spent at the document root, inside quotations and inside list items
(`test/presentation/paragraph_setting_test.dart`). It also measures the
half-beat spaced interval and the solid indented column. The heading suite checks
all six levels for proximity, a multiline `h1` for tight internal leading, and
a scaled mixed-script heading for clipping and phase
(`test/presentation/document_view_test.dart`). The complete rhythm test
then renders multiline headings, code, a rule and a tight list between
paragraphs and asserts every later paragraph's offset is a whole number of
beats (`test/presentation/document_view_test.dart`). The code-block suite also
measures the compact source line and proves both scrolled and wrapped surfaces
finish on a whole prose beat (`test/presentation/code_block_test.dart`).

## Transition

**Tables are knowingly off the beat.** Their height is content-driven, and
nothing rounds it. Bringhurst's rule permits a departure so long as the text
returns in phase afterwards, which it does not here — this is a real remaining
gap rather than a licensed exception.

Heading leading is settled per level, but a script can legitimately need taller
glyphs than the Latin face. Headings deliberately have no forced strut: Flutter
may expand the shaped text, and the completed block is reconciled from that real
height rather than clipping it to a Latin estimate
(`lib/api/render/document_view.dart`, `lib/api/render/document_view.dart`).
