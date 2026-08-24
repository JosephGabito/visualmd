# LiteralDocumentSearch

## Purpose and boundary

`LiteralDocumentSearch` implements the
[Document Search Port](../../02-application/06-document-search-port.md) with
Dart's built-in `RegExp` engine
(`lib/infrastructure/search/literal_document_search.dart`). It owns text
preparation, literal matching, and excerpts. It does not choose scope or know
which result is active on screen.

## Present wiring

For each document, the injected `DocumentParser` produces
`DocumentContent.text`; the result is cached by document identity
(`lib/infrastructure/search/literal_document_search.dart`). Searching
therefore ignores Markdown markers and link destinations that the page does
not show.

The query goes through `RegExp.escape`, then a case-insensitive Unicode
expression (`lib/infrastructure/search/literal_document_search.dart`).
`allMatches` supplies ordered, non-overlapping offsets, which become
`TextMatch` values (`lib/infrastructure/search/literal_document_search.dart`). Documents with no occurrence are omitted while
the input order is retained (`lib/infrastructure/search/literal_document_search.dart`).

## Inputs and outputs

In: a `SearchQuery` and application-scoped documents. Out: grouped
`DocumentSearchResult`s. Each excerpt takes up to 46 code units on either side,
folds whitespace for the shelf, and marks clipped edges with an ellipsis
(`lib/infrastructure/search/literal_document_search.dart`).

## Events

None. Infrastructure adapters do not publish search activity.

## Lifecycle

One adapter lives for the app session. Parsed visible text is cached against
the immutable `Document` instances in the current library. Opening another
library creates new instances; old entries remain small session data and leave
with the process.

## Failure and recovery

Reader input cannot become an invalid regular expression because it is escaped.
The Markdown parser's contract turns unsupported markup into visible raw text
rather than throwing, so a malformed document still remains searchable.

Focused adapter tests prove punctuation is literal, case is ignored, Markdown
marks are absent, empty documents are omitted, and library order survives
(`test/infrastructure/literal_document_search_test.dart`).

## Transition

The first measured performance limit should decide the next adapter: an
in-memory index or worker scan. A shell `grep` would have different semantics:
it cannot search browser-held folders and would match source punctuation rather
than the words shown on the page.
