# Document Content

## Purpose and boundary

`DocumentContent` is a document as the reader will meet it: an ordered list of
blocks, each block a list of runs
(`lib/domain/reading/content/document_content.dart`). It is the shape the
page is built from, and it belongs to the domain because *what a document is*
is a domain question, even though parsing markdown is not.

The model's one rule is that it carries the author's **reading text** exactly.
Markdown delimiters and escape backslashes have already served their grammar,
so `\*literal\*` arrives as `*literal*`; the punctuation itself is not changed.
A straight quote stays a straight quote here and `--` stays two hyphens
(`lib/domain/reading/content/inline.dart`). Deciding which marks
to *set* those as is a presentation decision, made later by the
[Inline Composer](../05-api/13-inline-composer.md). Keeping the two apart is
what lets search, outlines and copying see the words the author typed while
the page shows the words a typographer would have set.

It does not own layout, style, or how markdown is tokenised. That last is the
[Document Parser port](../02-application/04-document-parser-port.md) and its
[adapter](../03-infrastructure/markdown/01-markdown-document-parser.md).

## Present wiring

Two sealed hierarchies and a container.

**Blocks** — the shapes a page is built from
(`lib/domain/reading/content/block.dart`):

| Block | Carries | Defined at |
|-------|---------|------------|
| `ParagraphBlock` | runs | `lib/domain/reading/content/block.dart` |
| `HeadingBlock` | `level` 1–6, runs, and the `anchor` a link reaches it by | `lib/domain/reading/content/block.dart` |
| `AnchorBlock` | one explicit local navigation name and no reading text | `lib/domain/reading/content/block.dart` |
| `CodeBlock` | verbatim `code` and the `language` the author named | `lib/domain/reading/content/block.dart` |
| `MathBlock` | exact TeX for one display equation | `lib/domain/reading/content/block.dart` |
| `MermaidBlock` | exact Mermaid source for one diagram | `lib/domain/reading/content/block.dart` |
| `QuoteBlock` | blocks of its own | `lib/domain/reading/content/block.dart` |
| `ListBlock` | `ordered`, `start`, `loose`, and `ListItem`s | `lib/domain/reading/content/block.dart` |
| `TableBlock` | a head row and body rows of `TableCell` | `lib/domain/reading/content/block.dart` |
| `RuleBlock` | one structural separation and no searchable text | `lib/domain/reading/content/block.dart` |
| `RawBlock` | text the reader has no shape for | `lib/domain/reading/content/block.dart` |

**Runs** — what a line of text is made of
(`lib/domain/reading/content/inline.dart`): `TextRun`, whose punctuation and
internal spacing remain authored while source-formatting soft breaks have
already become reading text and backslash escapes have become their literal
ASCII punctuation, `CodeRun`
(verbatim, never re-set — `lib/domain/reading/content/inline.dart`), `MarkedRun` carrying one of
`InlineMark.emphasis | strong | strikethrough | subscript | superscript |
insertion` over its children (`lib/domain/reading/content/inline.dart`),
`MathRun` carrying exact inline TeX, `LinkRun`
(`lib/domain/reading/content/inline.dart`), `ImageRun`
(`lib/domain/reading/content/inline.dart`) and `LineBreakRun`, which is only
ever a line the author asked for with two trailing spaces or a backslash
(`lib/domain/reading/content/inline.dart`). Its text is one newline; the source
markers and indentation after them are formatting, not domain content.

`LinkRun` keeps three meanings separate: `children` are the visible label,
`href` is the destination, and the optional `title` is advisory metadata. Its
plain `text` is therefore only the children's reading text. Search, outlines,
anchors, copying and assistive technology receive what the reader can see;
neither a private destination nor a tooltip-like title silently enters the
document's prose (`lib/domain/reading/content/inline.dart`). Nested marks and
code remain children rather than being flattened, so a linked phrase keeps its
real typographic roles.

The model deliberately does not remember whether a reference link was full,
collapsed or shortcut notation. All three have already resolved to the same
label children, destination and title before entering the domain. An unresolved
reference does not become a `LinkRun`; its brackets remain ordinary authored
text instead.

The same economy applies to autolinks. Angle-bracket URI and email forms, bare
GFM web addresses and bare GFM emails all become `LinkRun`; the model records
their visible label and resolved destination, not which source spelling found
the link. A fragment destination is likewise ordinary `href` data here. The
API edge decides whether it scrolls inside the current document, opens another
library document, or leaves through a safe external scheme.

CommonMark also permits an empty inline-link label. The domain keeps that valid
shape — including its destination and title — while its `text` remains empty.
That is data fidelity, not permission to invent visible or accessible words at
the page edge (`lib/domain/reading/content/inline.dart`).

`ImageRun` likewise separates `source`, plain alternative text, and optional
title. Formatting inside an image description is flattened to its reading
words because CommonMark defines that result as the image's alternative, not
as styled prose. Inline, full-reference, collapsed-reference and
shortcut-reference spellings all become this same value. An empty alternative
is retained: it means decorative artwork and must not be replaced with the
filename (`lib/domain/reading/content/inline.dart`,
`lib/infrastructure/markdown/markdown_document_parser.dart`).

The model is deliberately ignorant of which valid delimiter spelling produced
a mark. Both `*emphasis*` and `_emphasis_` become the same
`MarkedRun(InlineMark.emphasis, ...)`; the stars or underscores have already
served their grammatical purpose and cannot leak into outlines, search,
selection or assistive text (`lib/domain/reading/content/inline.dart`).
The same boundary holds for `**strong**` and `__strong__`: both become one
`InlineMark.strong`, retaining importance as a typed mark without retaining its
source notation.

GFM's `~correction~` and `~~correction~~` likewise become one
`InlineMark.strikethrough`. Runs of three or more tildes are not eligible
notation and therefore remain authored reading text. The model records the
editorial meaning without deciding whether the page dims, colours or crosses
the words (`lib/domain/reading/content/inline.dart`).

GitHub's safe inline HTML writing forms also become marks rather than raw
tags. Paired `sub`, `sup`, and `ins` containers keep recursive Markdown
children as `subscript`, `superscript`, and `insertion`; attributes and tag
spelling are adapter detail. An unmatched or improperly nested tag has no
authority to restyle later prose, so its readable children remain unmarked
(`lib/domain/reading/content/inline.dart`,
`lib/infrastructure/markdown/markdown_document_parser.dart`).

GitHub's standalone `<a name="…"></a>` form becomes an `AnchorBlock`. It
deliberately contributes empty `text`: identity is available to navigation
without appearing in search, selection, copying, accessibility, or the
outline. An inline token is removed during block mapping because Flutter cannot
key a position inside selectable text without inserting a placeholder code
unit; a mixed raw HTML block is likewise never given a falsely relocated
target. Duplicate standalone names are first-wins and never alter generated
heading numbering
(`lib/domain/reading/content/block.dart`,
`lib/infrastructure/markdown/safe_html_text.dart`,
`lib/infrastructure/markdown/markdown_document_parser.dart`).

Marks remain recursive rather than being flattened. `***important***` is an
emphasis run containing a strong run, while `**important with _voice_ inside**`
keeps emphasis inside strength. That stack is semantic: presentation can add
the two independent cues, and plain-text consumers still receive only the
words. A delimiter run which CommonMark leaves literal remains in those words;
for example, the middle `**` in `*foo**bar*` is reading text, not decoration
(`lib/domain/reading/content/inline.dart`).

`RawBlock` is the model's promise that nothing is silently dropped: markup the
reader cannot set still reaches the page as its words
(`lib/domain/reading/content/block.dart`).

Mathematics follows the same source-authority rule as code without becoming
code. `MathRun` belongs to the sentence around it; `MathBlock` is a display
departure in the block sequence. Both expose only the TeX between delimiters as
their reading text. Delimiters are grammar, while typesetting, overflow and
rendering failure belong to the page
(`lib/domain/reading/content/block.dart`,
`lib/domain/reading/content/inline.dart`).

A Mermaid diagram follows that boundary at block scale. `MermaidBlock` keeps
the exact fence body as both source and searchable text. It knows nothing about
SVG, graph layout, zoom, or full screen; those are adapter and page concerns.
If rendering fails, the same value is sufficient to show and copy everything
the author supplied (`lib/domain/reading/content/block.dart`).

Generated heading anchors come from one rule, `HeadingAnchors`
(`lib/domain/reading/heading_anchor.dart`), which both this model and the
[Document Outline](03-document-outline.md) use — so a link found in the
outline always resolves on the page.

## Inputs and outputs

In: nothing. These are value objects; something else constructs them.

Out: `blocks`, `headings` in source order, `isEmpty`, and `text` — every word
without decoration, for anything that needs words rather than shapes
(`lib/domain/reading/content/document_content.dart`). Every block and
run offers the same `text`
(`lib/domain/reading/content/block.dart`,
`lib/domain/reading/content/inline.dart`).

## Events

None today. Value objects do not publish events. The
[Plugin Architecture](../07-roadmap/01-plugin-architecture.md) places any
future opened-document event in [ReadDocument](../02-application/02-read-document.md),
after a complete reading has been assembled.

## Lifecycle

Built once per document read and held on the `DocumentReading` that
[ReadDocument](../02-application/02-read-document.md) returns
(`lib/application/use_cases/read_document.dart`). Immutable, so it may be
rebuilt or discarded freely.

## Failure and recovery

These immutable values add no failure mode of their own. Markup the parser
cannot map becomes a `RawBlock` rather than being discarded, and an empty
document is
`DocumentContent.empty` (`lib/domain/reading/content/document_content.dart`)
— an empty page rather than an exception. Empty content is tested at
`test/infrastructure/markdown_document_parser_test.dart`; the same suite and
`test/infrastructure/safe_html_text_test.dart` directly exercise safe raw
fallback, comments and dangerous HTML source.

## Transition

The domain still does not load an image or decide whether its source is local.
Those are application and platform questions handled by
[Document Image](../05-api/23-document-image.md). Syntax highlighting reads
`CodeBlock.language` through the presentation contract and colours source in
the renderer. No token moved into this model: a highlighted range is still not
a domain concept.
