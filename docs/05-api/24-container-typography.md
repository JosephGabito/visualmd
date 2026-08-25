# Container Typography

## Purpose and boundary

Container typography sets quotations, lists, list items and task items without
inventing another prose system. It owns indentation, markers, relationships
between child blocks and the return to the body grid
(`lib/api/render/document_view.dart`).

It does not parse Markdown. The infrastructure adapter supplies recursive
[`QuoteBlock`](../01-domain/05-document-content.md) and `ListBlock` trees before
the API ring sees them (`lib/infrastructure/markdown/markdown_document_parser.dart`).
It also does not choose the body face, size or leading; [Reading Theme](14-reading-theme.md)
has already derived those from the selected scale and font metrics.

The governing rule is simple: **a container may compress the space between its
child blocks, but it never compresses the leading of running prose**. A wrapped
list item is still prose. Density belongs around its paragraph, not between the
paragraph's baselines.

## Present wiring

`_BlockSequence` is recursive. The document root, each quotation and every list
item all walk the same sealed `Block` model
(`lib/api/render/document_view.dart`). That makes a quote containing a list and
a list containing a quote ordinary composition rather than special cases.

The contexts differ only in how much external space they spend:

| Context | Space between children | Prose leading |
|---|---:|---:|
| Document root | One beat for ordinary departures | One body beat |
| Quotation | Half a beat, or none between indented paragraphs | One body beat |
| Tight list item | None | One body beat |
| Loose list item | Half a beat | One body beat |
| Tight list items | None | One body beat |
| Loose list items | Half a beat | One body beat |

`ReadingTheme.spaceAfterInContainer` owns that arithmetic
(`lib/api/render/reading_theme.dart`). The `Paragraph` inside each context still
receives the same body style and forced strut
(`lib/api/render/document_view.dart`). Inline code, links and marks therefore
cannot change the line box, and neither can nesting. When paragraph marking is
indented, consecutive paragraphs remain solid and the later paragraph carries
the indent; spacing and indentation never signal the same boundary twice.

Half-beat interiors can finish between body baselines. The outermost
`_RhythmicContainer` measures the completed recursive tree, includes the
external space its parent will spend, and adds only the correction needed below
its content. Nested quotes and lists keep their intrinsic height; if each one
rounded independently, every level would accumulate an invisible blank beat.
Following prose consequently returns on the grid once, without a top margin or
a changed child line-height (`lib/api/render/document_view.dart`).

Quotations use one directional accent rule plus one quieter text tone. They are
not italic: italic marks emphasis and slows continuous reading. The rule uses
the authored reading edge, so Arabic and Hebrew quotations place it on the
right (`lib/api/render/document_view.dart`). Each nested quote repeats the rule
because depth is structural information, but adds no shadow, panel or new face.

List markers hang outside the shared text edge. `_List` measures every visible
marker and gives the gutter to the widest one, so a nine-digit starting number
cannot wrap or clip. Earlier and later items keep one established text edge,
including long continuation lines (`lib/api/render/document_view.dart`).
Unordered source markers become the same quiet bullet because `-`, `*` and `+`
are equivalent reading structure; ordered sequences keep the authored start.

Task markers occupy the same first-line box as bullets and numbers. Their
checked state is exposed to semantics as well as shown by the icon. The text
remains ordinary recursively composed inline content
(`lib/api/render/document_view.dart`).

## Inputs and outputs

In: `QuoteBlock`, `ListBlock`, `ListItem`, the current `ReadingTheme`, an
`InlineComposer`, the code highlighter, anchor keys and search offsets.

Out: directional Flutter widget trees whose child blocks remain searchable,
linkable and reachable by heading anchor. No container mutates the domain
content or the selected theme.

## Events

None. Links and heading navigation continue through the same callbacks and keys
used at the document root. Task checkboxes describe authored state; this reader
does not edit them.

## Lifecycle

Containers are stateless and rebuilt with the document, width or theme. Marker
measurement happens during build from the active marker style and text scaler,
so accessibility scaling and a changed reading face establish a new gutter
instead of inheriting stale pixels.

## Failure and recovery

The sealed block switch makes every supported child renderable at every depth.
An empty list produces an empty column. A very wide marker consumes the width it
needs rather than painting over item text; the remaining prose reflows. Deep
nesting narrows the available measure but never lowers the text size or leading.

Parser tests cover all marker spellings, loose items, authored starts, mixed
trees, task states and compound list items
(`test/infrastructure/markdown_document_parser_test.dart`). Widget tests measure
tight and loose relationships, wide gutters, bidirectional quote rules, task
semantics and the grid after nested containers
(`test/presentation/document_view_test.dart`).

## Transition

The recursive contract is complete for CommonMark quotations and lists plus
GFM task items. Future container extensions must supply the same three things:
a domain block, a recursive renderer, and a proof that the completed departure
returns running prose to the body grid. They must not obtain density by silently
changing the prose leading.
