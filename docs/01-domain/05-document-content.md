# Document Content

## Purpose and boundary

`DocumentContent` is a document as the reader will meet it: an ordered list of
blocks, each block a list of runs
(`lib/domain/reading/content/document_content.dart:4-18`). It is the shape the
page is built from, and it belongs to the domain because *what a document is*
is a domain question, even though parsing markdown is not.

The model's one rule is that it carries the author's text **exactly as
written**. A straight quote stays a straight quote here; `--` stays two
hyphens (`lib/domain/reading/content/inline.dart:1-11`). Deciding which marks
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
(`lib/domain/reading/content/block.dart:4-9`):

| Block | Carries | Defined at |
|-------|---------|------------|
| `ParagraphBlock` | runs | `lib/domain/reading/content/block.dart:11-18` |
| `HeadingBlock` | `level` 1–6, runs, and the `anchor` a link reaches it by | `lib/domain/reading/content/block.dart:20-36` |
| `CodeBlock` | verbatim `code` and the `language` the author named | `lib/domain/reading/content/block.dart:38-47` |
| `QuoteBlock` | blocks of its own | `lib/domain/reading/content/block.dart:49-56` |
| `ListBlock` | `ordered`, `start`, `loose`, and `ListItem`s | `lib/domain/reading/content/block.dart:58-90` |
| `TableBlock` | a head row and body rows of `TableCell` | `lib/domain/reading/content/block.dart:92-114` |
| `RuleBlock` | nothing | `lib/domain/reading/content/block.dart:116-121` |
| `RawBlock` | text the reader has no shape for | `lib/domain/reading/content/block.dart:123-130` |

**Runs** — what a line of text is made of
(`lib/domain/reading/content/inline.dart:5-85`): `TextRun`, `CodeRun`
(verbatim, never re-set — `:29-41`), `MarkedRun` carrying one of
`InlineMark.emphasis | strong | strikethrough` over its children (`:43-55`),
`LinkRun` (`:57-66`), `ImageRun` (`:68-77`) and `LineBreakRun`, which is only
ever a break the author asked for with two trailing spaces (`:79-86`).

`RawBlock` is the model's promise that nothing is silently dropped: markup the
reader cannot set still reaches the page as its words
(`lib/domain/reading/content/block.dart:123-129`).

Anchors come from one rule, `HeadingAnchors`
(`lib/domain/reading/heading_anchor.dart:7-29`), which both this model and the
[Document Outline](03-document-outline.md) use — so a link found in the
outline always resolves on the page.

## Inputs and outputs

In: nothing. These are value objects; something else constructs them.

Out: `blocks`, `headings` in source order, `isEmpty`, and `text` — every word
without decoration, for anything that needs words rather than shapes
(`lib/domain/reading/content/document_content.dart:11-17`). Every block and
run offers the same `text`
(`lib/domain/reading/content/block.dart:7-8`,
`lib/domain/reading/content/inline.dart:8-10`).

## Events

None today. Value objects do not publish events. The
[Plugin Architecture](../07-roadmap/01-plugin-architecture.md) places any
future opened-document event in [ReadDocument](../02-application/02-read-document.md),
after a complete reading has been assembled.

## Lifecycle

Built once per document read and held on the `DocumentReading` that
[ReadDocument](../02-application/02-read-document.md) returns
(`lib/application/use_cases/read_document.dart:54-58`). Immutable, so it may be
rebuilt or discarded freely.

## Failure and recovery

These immutable values add no failure mode of their own. Markup the parser
cannot map becomes a `RawBlock` rather than being discarded, and an empty
document is
`DocumentContent.empty` (`lib/domain/reading/content/document_content.dart:9`)
— an empty page rather than an exception. Empty content is tested at
`test/infrastructure/markdown_document_parser_test.dart:262-264`; direct
coverage of the raw fallback remains listed in [Invariants](04-invariants.md).

## Transition

Images are carried but not resolved (`ImageRun` holds a `source` nobody reads
yet); relative image loading is in the
[backlog](../07-roadmap/02-backlog.md). If syntax highlighting arrives,
`CodeBlock.language` is already the field it needs, and the colouring belongs
in the renderer rather than here — a highlighted token is not a domain
concept.
