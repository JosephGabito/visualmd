# Document Parser Port

## Purpose and boundary

`DocumentParser` is the application's way of asking for a completed document's
blocks without knowing how markdown is tokenised. Its sibling
`IncrementalDocumentParser` opens one append-oriented parse generation
(`lib/application/ports/document_parser.dart`). Both return
[`DocumentContent`](../01-domain/05-document-content.md); the second returns
successive revisioned snapshots instead of replacing an untyped block list.

The port exists because parsing markdown and *defining* a document are
different jobs. CommonMark is a large specification with a long tail of
corners, and keeping up with it is technical work that belongs at the edge;
what a document *is* — paragraphs, headings, a quotation holding blocks of its
own — is a domain question and stays in the domain
(`lib/application/ports/document_parser.dart`).

## Present wiring

Declared in `application/ports/`, like every port: named for the need, not for
the technology that will satisfy it. Implemented together by
[MarkdownDocumentParser](../03-infrastructure/markdown/01-markdown-document-parser.md),
and handed to [ReadDocument](02-read-document.md) at the composition root.
Completed local files use `DocumentParser`. The incremental session is proven
independently before a generated-source transport is connected to it.

## Inputs and outputs

| Member | Type | Contract |
|--------|------|----------|
| `parse(String markdown)` | `DocumentContent` | Return the document's blocks in source order. Carry the author's text exactly; decide nothing about how it looks. Never throw: markup with no shape becomes `RawBlock`. |
| `startSession()` | `IncrementalDocumentParserSession` | Begin one append-only source generation with an empty revision-zero snapshot. |
| `append(String source)` | `DocumentContent` | Accept exact new source, preserve committed block identities, and replace only provisional output unless document-global syntax requires a semantic rebase. |
| `finish()` | `DocumentContent` | Fence later appends and return the canonical completed parse with every block committed. |

Both contracts are synchronous because they perform no I/O. Stream batching
will decide when to call the session, and profiling will decide whether the
same contract belongs behind a persistent worker isolate. An `await` around
the current parser would not move its CPU work off the UI isolate.

## Events

None. A port answers an application need; if the roadmap's `DocumentOpened`
event gains a subscriber, it belongs to the use case that completes the open
operation ([Plugin Architecture](../07-roadmap/01-plugin-architecture.md)).

## Lifecycle

The complete parser is stateless by contract. The one implementation is a
`const` object built once in `lib/main.dart`. Each incremental session owns one
generation's source buffer, Markdown reference context, heading-anchor ledger,
and committed/provisional block boundary, then becomes immutable after
`finish()` (`lib/infrastructure/markdown/markdown_document_parser.dart`).

## Failure and recovery

The port has no expected parse failure. A reader opening an unfamiliar markdown
construct should still receive a useful document, so the adapter returns a
`RawBlock` for elements the domain does not model
(`lib/infrastructure/markdown/markdown_document_parser.dart`), and an
empty document simply has no blocks.

Appending after `finish()` throws `StateError`, fencing late transport work.
Markdown which can reinterpret earlier content, such as a newly committed
reference definition, triggers an explicit semantic rebase rather than leaving
stale committed output. Ordinary prose continues to parse only its unfinished
tail.

## Transition

A transport coordinator can now add sequence validation, adaptive batching,
cancellation, and stale-generation fencing without changing Markdown or block
semantics. Outline and search projections still need to consume the same
mutations, and document-global references need a dependency index before their
rare semantic rebase can become proportional only to affected blocks.
