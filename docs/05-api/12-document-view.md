# Document View

## Purpose and boundary

`DocumentView` walks [`DocumentContent`](../01-domain/05-document-content.md)
and builds its blocks (`lib/api/render/document_view.dart`). It owns
layout and rhythm, while [Reading Theme](14-reading-theme.md) owns styles and
[Inline Composer](13-inline-composer.md) owns text shaping.

This is the reader's own renderer rather than a general-purpose markdown
widget, because the central rules cannot be expressed in a style sheet
(`lib/api/render/document_view.dart`):

- **Prose, code and tables want different overflow rules.** Prose reflows;
  code keeps its lines; tables keep short fields natural and long cells
  readable. Code and tables scroll locally when they do not fit.
- **The vertical rhythm is a rule, not a series of paddings.** Every gap is a
  whole number of beats, and the space above a heading belongs to the heading
  rather than to the paragraph above it. See
  [Vertical Rhythm](../04-presentation/11-vertical-rhythm.md).
- **Paragraphs use one signal.** Indented prose is solid; spaced prose is
  flush. The same sequence rule is applied recursively inside quotations and
  list items.

## Present wiring

A `LayoutBuilder` takes `proseWidth` and `wideWidth` from the theme
(`lib/api/render/document_view.dart`). Blocks use a **fixed** width so
code grounds span their column and prose wraps at its measure
(`lib/api/render/document_view.dart`). Code and tables take the wide
width; everything else takes prose (`lib/api/render/document_view.dart`).

`_BlockSequence` owns order-sensitive gaps and indents at every depth
(`lib/api/render/document_view.dart`). Its `theme.gapBefore(…)` spends
one beat between ordinary blocks and none after a heading, because the
heading's own reconciled box already carries its quieter half-beat below
(`lib/api/render/document_view.dart`).

### The paragraph rules

`ParagraphRules` states the two decisions this file makes about paragraphs
(`lib/api/render/document_view.dart`), both of which exist to stop the
page saying the same thing twice:

| Rule | Answer | Why |
|------|--------|-----|
| `indents` | Only when the previous block is a paragraph (`lib/api/render/document_view.dart`) | An indent signals separation. The paragraph opening a document or a section has nothing behind it; one resuming after a list, quotation or code block is already separated by that block's space |
| `separates` | No gap between consecutive paragraphs when indented (`lib/api/render/document_view.dart`) | An indented column is solid. A gap *and* an indent would repeat the same separation signal |

The marking comes from the scale and the sequence passes each block its indent;
the block does not work out whether it is indented (`lib/api/render/document_view.dart`).

Each block type is built by `_BlockView`
(`lib/api/render/document_view.dart`):

- **Paragraph** — composed with the theme in hand, which inside a quotation is
  the quoting one, handed its indent, and given the theme's strut so a code span
  cannot push a line off the beat
  (`lib/api/render/document_view.dart`). Setting it is
  [Paragraph](15-paragraph.md)'s job.
- **Heading** — wrapped in a `KeyedSubtree` keyed by anchor so the outline can
  bring it into view, then handed to `_RhythmicHeading`. Its lines keep their
  natural display leading; after shaping, the render object adds half a beat
  below and only enough above to make the complete box consume whole beats
  (`lib/api/render/document_view.dart`, `lib/api/render/document_view.dart`). There is no forced
  strut, so a taller fallback script may establish the height it actually
  needs.
- **Code** — a [`ReadableCodeBlock`](11-code-block.md) with half a beat of
  padding above and below and **no border**: its own ground already says what
  it is, and a border is both a second signal and a height that breaks the grid
  (`lib/api/render/document_view.dart`).
- **Quotation** — `_Quote`: a 2 px accent rule and blocks re-rendered one shade
  back with `ReadingTheme.quoting`. Two signals, not three: no italic
  (`lib/api/render/document_view.dart`).
- **List** — `_List`: markers hang in a gutter so every item shares a left edge.
  Loose items get one beat; tight items follow like paragraph lines. Markers
  are muted signposts, and task items show a checkbox
  (`lib/api/render/document_view.dart`).
- **Table** — `_Table`: alignment as the author asked, a panel-coloured head
  row, ragged-row padding and locally scrolling overflow
  (`lib/api/render/document_view.dart`,
  `lib/api/render/reading_theme.dart`).
- **Rule** — a centred one-pixel divider inside a box exactly one beat tall,
  so prose after it returns to the grid (`lib/api/render/document_view.dart`).
- **RawBlock** — muted text (`lib/api/render/document_view.dart`).

### The table-width formula

For cell `i` in column `j`, let `w(text)` be its measured rendered width,
`R = w(55 average characters)`, and `p` one horizontal cell inset:

`mᵢⱼ = min(w(textᵢⱼ), R)` and `Cⱼ = 2p + maxᵢ(mᵢⱼ)`.

The table minimum is `T = Σⱼ Cⱼ`. If `T > available`, each rendered column is `Wⱼ = Cⱼ` and the table scrolls. Otherwise, spare width is proportional:
`Wⱼ = Cⱼ × available / T`. Thus an all-short `MAE1` column stays natural,
while a long prose cell grows only to the researched 55-character measure.

## Inputs and outputs

| In | Type | From |
|----|------|------|
| `content` | `DocumentContent` | `DocumentReading.content` |
| `theme` | `ReadingTheme` | Built by the [reading pane](04-reading-pane.md) |
| `anchorKeys` | `Map<String, GlobalKey>` | Owned by the pane; filled in as headings build |
| `onTapLink` | `void Function(String href)?` | The pane's link handler |

Out: nothing directly. Links report through the composer; the pane reads
`anchorKeys` to scroll and to track the active heading.

## Events

None today. The **reading-pane block** slot belongs here: a contributor that
renders a fenced language — mermaid, or syntax highlighting — would be
consulted in `_BlockView`'s `CodeBlock` case
(`lib/api/render/document_view.dart`). See the
[plugin architecture](../07-roadmap/01-plugin-architecture.md).

## Lifecycle

Stateless, rebuilt with the document, theme or width. The pane owns
`anchorKeys` and clears it when a different document arrives.

## Failure and recovery

The sealed-block switch is exhaustive, so a new block requires a renderer.
A short table row is padded rather than throwing
(`lib/api/render/document_view.dart`), and a `RawBlock` shows its
words (`lib/api/render/document_view.dart`).

`test/presentation/document_view_test.dart` covers column widths and
table overflow, all six heading levels, multiline and scaled mixed-script
headings, rhythm through rules and lists, tonal hierarchy, anchors, markers,
task lists and quotation treatment.

## Transition

Everything builds at once inside one scroll view, which keeps `ensureVisible`
exact but is the first thing to revisit for very long documents. Wider code
and tables whose content-driven height is still off the beat remain in the
[backlog](../07-roadmap/02-backlog.md).
