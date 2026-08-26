# Document View

## Purpose and boundary

`DocumentView` walks [`DocumentContent`](../01-domain/05-document-content.md)
and builds its blocks (`lib/api/render/document_view.dart`). It owns
layout and rhythm, while [Reading Theme](14-reading-theme.md) owns styles and
[Inline Composer](13-inline-composer.md) owns text shaping.

This is the reader's own renderer rather than a general-purpose markdown
widget, because the central rules cannot be expressed in a style sheet
(`lib/api/render/document_view.dart`):

- **Prose, code, mathematics, diagrams and tables want different overflow rules.** Prose reflows;
  code keeps its lines; display mathematics keeps its two-dimensional notation;
  diagrams begin fitted and become pannable; tables keep short fields natural and long cells readable. Each wide shape
  scrolls locally when it does not fit.
- **The vertical rhythm is a rule, not a series of paddings.** Every external
  gap is emitted after the block that owns it; nothing adds space above itself.
  See
  [Vertical Rhythm](../04-presentation/11-vertical-rhythm.md).
- **Paragraphs use one signal.** Indented prose is solid; spaced prose is
  flush. The same sequence rule is applied recursively inside quotations and
  list items.

## Present wiring

A `LayoutBuilder` takes `proseWidth` and `wideWidth` from the theme
(`lib/api/render/document_view.dart`). Blocks use a **fixed** width so
code grounds span their column and prose wraps at its measure
(`lib/api/render/document_view.dart`). Code, display mathematics, Mermaid diagrams and tables take the wide
width; everything else takes prose (`lib/api/render/document_view.dart`).

`_BlockSequence` owns order-sensitive gaps and indents at every depth
(`lib/api/render/document_view.dart`). After rendering the current block it
spends `theme.spaceAfter(current, next)`, then advances. The final block spends
nothing. Quotations and list items recurse through the same sequence, so there
is one spacing direction and one owner everywhere
(`lib/api/render/reading_theme.dart`, `lib/api/render/document_view.dart`).

### The paragraph rules

`ParagraphRules` states the two decisions this file makes about paragraphs
(`lib/api/render/document_view.dart`), both of which exist to stop the
page saying the same thing twice:

| Rule | Answer | Why |
|------|--------|-----|
| `indents` | Only when the previous block is a paragraph (`lib/api/render/document_view.dart`) | An indent signals separation. The paragraph opening a document or a section has nothing behind it; one resuming after a list, quotation or code block is already separated by that block's space |
| `spaceAfter` | Half a beat for spaced paragraphs; none for indented ones (`lib/api/render/reading_theme.dart`) | A full blank line is too open; a gap *and* an indent would repeat the same signal |

The scale supplies the marking; the sequence passes each block its indent
(`lib/api/render/document_view.dart`).

Each block type is built by `_BlockView`
(`lib/api/render/document_view.dart`):

- **Paragraph** — composed with the theme in hand, which inside a quotation is
  the quoting one, handed its indent, and given the theme's strut so a code span
  cannot push a line off the beat. It sets flush-start/ragged-end and reflows
  at the measured prose width. Each paragraph derives its own reading edge from
  its first strong Unicode character (`lib/api/render/document_view.dart`).
  Setting it is [Paragraph](15-paragraph.md)'s job.
- **Heading** — wrapped in a `KeyedSubtree` keyed by anchor so the outline can
  bring it into view, then handed to `_RhythmicHeading`. Its lines keep their
  natural display leading. The sequence owns its outgoing half-beat; after
  shaping, the render object accounts for that known space and keeps only the
  grid correction inside the heading. There is no forced strut, so a taller
  fallback script may establish the height it actually needs
  (`lib/api/render/document_view.dart`). A semantics annotation carries both
  the heading role and its authored level from one through six, so the visual
  hierarchy is also available to assistive technology. `ReadingDirection`
  takes the first strongly directional character as the block's base direction,
  so Arabic and Hebrew headings align and wrap from the side they are read
  using generated Unicode 17 bidi classes rather than a BMP script heuristic
  (`lib/api/render/reading_direction.dart`).
- **Custom anchor** — attached as a zero-size key to the following visible
  block. It creates neither a line box nor an outgoing gap; a trailing target
  remains a zero-size keyed box. Inline anchors are not given false geometry
  (`lib/api/render/document_view.dart`).
- **Code** — a [`ReadableCodeBlock`](11-code-block.md) with half a beat of
  padding above and below and **no border**: its own ground already says what
  it is, and a border is both a second signal and a height that breaks the grid
  (`lib/api/render/document_view.dart`).
- **Mathematics** — a [Mathematical Expression](25-mathematical-expression.md)
  on the paper itself. A display equation scrolls locally at the wide measure
  and its completed height is reconciled to the body grid. A paragraph that
  contains inline mathematics is likewise reconciled after the equation has
  established its real line box (`lib/api/render/document_view.dart`).
- **Mermaid** — a [Mermaid Diagram](26-mermaid-diagram.md) fitted into a
  bounded reading viewport. Dragging and zooming explore that same vector
  model locally, while full screen gives dense graphs the window without
  changing document scroll or domain state (`lib/api/render/document_view.dart`,
  `lib/api/widgets/mermaid_diagram.dart`).
- **Quotation** — `_Quote`: a 2 px accent rule at the authored reading edge and
  blocks re-rendered one shade back with `ReadingTheme.quoting`. Its child
  blocks use compact half-beat relationships while their prose keeps body
  leading. Two signals, not three: no italic
  (`lib/api/render/document_view.dart`).
- **List** — `_List`: markers hang in a gutter at each item's reading edge.
  An RTL item places its marker to the right; an LTR item places it to the left.
  The widest marker establishes the gutter, so large authored starts remain
  one line and every item keeps a shared text edge. Loose items get half a beat;
  tight items follow like paragraph lines without changing their leading.
  Markers are muted signposts, and task items expose their checked state both
  visually and through semantics
  (`lib/api/render/document_view.dart`).
- **Table** — `_Table`: alignment as the author asked, a panel-coloured head
  row, ragged-row padding and locally scrolling overflow. Each cell resolves
  direction independently, because adjacent languages need not share an edge
  (`lib/api/render/document_view.dart`,
  `lib/api/render/reading_theme.dart`).
  Header-only and one-column tables remain tables; wide and extremely uneven
  shapes keep their own horizontal scroller rather than widening the page.
  Numeric cells use lining tabular figures. Flutter contributes table, row and
  cell semantics, and Visual MD marks the authored head as column headers. The
  surrounding reading pane keeps every cell selectable. `TableBlock.text`
  separately preserves rows as newlines and cell boundaries as tabs for search
  and source offsets; structured cross-cell clipboard output remains open
  (`lib/domain/reading/content/block.dart`,
  `lib/api/widgets/reading_pane.dart`).
  Rows keep their content-driven height, then the completed surface and its
  forward-owned gap reconcile together so following prose returns to the body
  grid without padding every row (`lib/api/render/document_view.dart`).
- **Rule** — a centred one-pixel divider in the quiet border tone, constrained
  to the prose measure inside a box exactly one beat tall, so prose after it
  returns to the grid. A non-interactive semantics node names the structure
  “Thematic break” without making it a focus target
  (`lib/api/render/document_view.dart`).
- **RawBlock** — muted text with its authored reading direction
  (`lib/api/render/document_view.dart`).

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
| `codeHighlighter` | `CodeHighlighter` | Framework-free source-range contributor, plain by default |
| `anchorKeys` | `Map<String, GlobalKey>` | Owned by the pane; filled in as headings build |
| `customAnchorKeys` | `Map<String, GlobalKey>` | Owned separately by the pane; filled by eligible standalone HTML anchors without entering the outline |
| `onTapLink` | `void Function(String href)?` | The pane's link handler |

Out: nothing directly. Links report through the composer; the pane reads the
two anchor maps to scroll, while active-heading tracking consults only heading
keys.

## Events

No events. `_BlockView` already consults the injected `CodeHighlighter` in its
`CodeBlock` case and supplies the ranges to `InlineComposer`
(`lib/api/render/document_view.dart`). A **reading-pane block** contributor for
rendered artifacts such as Mermaid would be a separate future slot; syntax
ranges do not replace the code widget. See the
[plugin architecture](../07-roadmap/01-plugin-architecture.md).

## Lifecycle

Stateless, rebuilt with the document, theme or width. The pane owns both key
maps and clears them when a different document arrives or the current source
changes beneath the same identity.

## Failure and recovery

The sealed-block switch is exhaustive, so a new block requires a renderer.
A short table row is padded rather than throwing
(`lib/api/render/document_view.dart`), and a `RawBlock` shows its
words (`lib/api/render/document_view.dart`).

`test/presentation/document_view_test.dart` covers degenerate and extreme table
shapes, local overflow, numeric figures and table semantics; multiline geometry
at all six heading levels, scaled mixed-script
and unbreakable headings, heading-level semantics and authored direction for
paragraphs, lists and table cells,
thematic-break geometry and semantics, rhythm through rules and lists, tonal
hierarchy, anchors, marker geometry, nested container rhythm, task semantics and
bidirectional quotation treatment. The full recursive contract is documented in
[Container Typography](24-container-typography.md).

## Transition

Everything builds at once inside one scroll view, which keeps `ensureVisible`
exact but is the first thing to revisit for very long documents. Wider code
remains in the [backlog](../07-roadmap/02-backlog.md).
