# Document Parser Port

## Purpose and boundary

`DocumentParser` is the application's way of asking for a document's blocks
without knowing how markdown is tokenised
(`lib/application/ports/document_parser.dart`). One method: source in,
[`DocumentContent`](../01-domain/05-document-content.md) out.

The port exists because parsing markdown and *defining* a document are
different jobs. CommonMark is a large specification with a long tail of
corners, and keeping up with it is technical work that belongs at the edge;
what a document *is* — paragraphs, headings, a quotation holding blocks of its
own — is a domain question and stays in the domain
(`lib/application/ports/document_parser.dart`).

## Present wiring

Declared in `application/ports/`, like every port: named for the need, not for
the technology that will satisfy it. Implemented once, by
[MarkdownDocumentParser](../03-infrastructure/markdown/01-markdown-document-parser.md),
and handed to [ReadDocument](02-read-document.md) at the composition root.

## Inputs and outputs

| Member | Type | Contract |
|--------|------|----------|
| `parse(String markdown)` | `DocumentContent` | Return the document's blocks in source order. Carry the author's text exactly; decide nothing about how it looks. Never throw: markup with no shape becomes `RawBlock`. |

The return type is synchronous because the current implementation performs no
I/O and `ReadDocument` needs the result as one value. This is a present design
choice rather than a performance guarantee; large-document measurements would
be needed before deciding whether parsing should move off the UI isolate.

## Events

None. A port answers an application need; if the roadmap's `DocumentOpened`
event gains a subscriber, it belongs to the use case that completes the open
operation ([Plugin Architecture](../07-roadmap/01-plugin-architecture.md)).

## Lifecycle

Stateless by contract. The one implementation is a `const` object built once
in `lib/main.dart` and shared for the life of the session; any anchor
numbering it needs is created and discarded per call
(`lib/infrastructure/markdown/markdown_document_parser.dart`).

## Failure and recovery

The port has no expected parse failure. A reader opening an unfamiliar markdown
construct should still receive a useful document, so the adapter returns a
`RawBlock` for elements the domain does not model
(`lib/infrastructure/markdown/markdown_document_parser.dart`), and an
empty document simply has no blocks.

## Transition

A second markdown implementation can replace the current adapter without
changing the use case as long as it preserves `DocumentContent` semantics. If
measurements show visible stalls on large files, an asynchronous parsing path
can be designed explicitly rather than assuming the current synchronous shape
is cost-free.
