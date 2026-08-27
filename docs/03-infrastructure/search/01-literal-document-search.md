# LiteralDocumentSearch

## Purpose and boundary

`LiteralDocumentSearch` implements the
[Document Search Port](../../02-application/06-document-search-port.md) with
Dart's built-in `RegExp` engine
(`lib/infrastructure/search/literal_document_search.dart`). It owns text
preparation, literal matching, and excerpts. It does not choose scope or know
which result is active on screen.

## Present wiring

On the first search of a document, the injected `DocumentParser` produces
`DocumentContent.text`; that visible text is cached by stable document identity
(`lib/infrastructure/search/literal_document_search.dart`). Searching
therefore ignores Markdown markers and link destinations that the page does
not show. Escape backslashes are grammar markers too: a reader can find
`*literal*` from source written as `\*literal\*`, while searching for the
discarded backslash notation returns nothing.

The query goes through `RegExp.escape`, then a case-insensitive Unicode
expression (`lib/infrastructure/search/literal_document_search.dart`).
`allMatches` supplies ordered, non-overlapping UTF-16 offsets, which become
`TextMatch` values (`lib/infrastructure/search/literal_document_search.dart`). Documents with no occurrence are omitted while
the input order is retained (`lib/infrastructure/search/literal_document_search.dart`).

Those exact offsets remain the search contract, but excerpts expand their two
outer cuts to extended grapheme boundaries. A clipped result can therefore
begin with a complete combining or emoji sequence, never half a surrogate or
an orphaned modifier (`lib/infrastructure/search/literal_document_search.dart`).

## Inputs and outputs

In: a `SearchQuery` and application-scoped documents. Out: grouped
`DocumentSearchResult`s. Each excerpt takes up to 46 code units on either side,
folds whitespace for the shelf, and marks clipped edges with an ellipsis
(`lib/infrastructure/search/literal_document_search.dart`).

## Events

None. Infrastructure adapters do not publish search activity.

## Lifecycle

One adapter lives for the app session. It retains derived visible text in
least-recently-used order, capped by an estimated 64 MiB UTF-16 payload budget;
source text is never retained. A projection larger than the entire budget is
used for the current query and immediately released. `SearchDocuments` routes
source invalidation, library retention, and session clearing through the index
contract (`lib/infrastructure/search/literal_document_search.dart`).

## Failure and recovery

Reader input cannot become an invalid regular expression because it is escaped.
The Markdown parser's contract turns unsupported markup into visible raw text
rather than throwing, so a malformed document still remains searchable.

Focused adapter tests prove punctuation is literal, case is ignored, Markdown
marks and escape notation are absent, Unicode excerpts keep complete
graphemes, empty documents are omitted, and library order survives
(`test/infrastructure/literal_document_search_test.dart`).

## Transition

The retained projection makes query refinement avoid repeated IO and Markdown
parsing. Matching still examines every projection, so the next measurement can
decide whether an inverted token or n-gram index earns its memory and mutation
cost. A shell `grep` would have different semantics: it cannot search
browser-held folders and would match source punctuation rather than the words
shown on the page.
