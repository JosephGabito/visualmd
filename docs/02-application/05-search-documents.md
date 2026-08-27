# SearchDocuments

## Purpose and boundary

`SearchDocuments` chooses the documents in scope, streams their sources, and
delegates matching through the [Document Search Port](06-document-search-port.md)
(`lib/application/use_cases/search_documents.dart`). It searches either
the whole open `Library` or one `DocumentId`; it does not retain source,
parse Markdown, match strings, construct excerpts, or render results.

## Present wiring

`execute(text, within:)` returns immediately for an empty field, then reads the
current library through `LibraryRepository` (`lib/application/use_cases/search_documents.dart`).
Without `within`, documents are visited in shelf order. For each one,
`DocumentSourceReader` obtains the source, the search port receives a
source-backed one-item iterable, and the source is released before the next
document is visited (`lib/application/use_cases/search_documents.dart`). With
an id, the same pipeline visits exactly that document.

Results are rebound to the metadata-only `Document` from the library. Search
therefore neither fills the reading cache nor accidentally retains every
matched source through its result list. The search and reading cache contract
is exercised together in `test/application/read_document_cache_test.dart`.

Every execution receives a monotonically increasing request revision. Starting
a newer query, including clearing the field, supersedes the older one. The old
scan checks that revision after repository lookup, source IO and adapter work;
it releases its current source and returns no stale partial result before
opening another file (`lib/application/use_cases/search_documents.dart`). This
does not pretend synchronous parsing can be interrupted midway, but it bounds
wasted work to the one document already in progress rather than the remaining
library.

The composition root gives reading and search the same `DocumentSourceReader`,
then injects the use case into `ReaderController` (`lib/main.dart`).

## Inputs and outputs

| Input | Meaning |
|-------|---------|
| `String text` | literal query; empty means no results |
| `DocumentId? within` | null for the library, an id for current-document scope |

The output is `Future<List<DocumentSearchResult>>`, preserving document and
match order from the port.

## Events

None. A search neither opens nor changes a document. Selecting a result later
uses the existing document-opening path in the API.

## Lifecycle

One stateful use-case instance lives for the application session. A search
has bounded source residency: at most one source-backed document is handed to
the adapter at a time. `LiteralDocumentSearch` does not cache source text
(`lib/infrastructure/search/literal_document_search.dart`). The request
revision is session-local coordination only; it retains neither queries nor
results.

## Failure and recovery

No open library throws `NoLibraryOpen`; a scoped id absent from the current
library throws `DocumentNotFound` (`lib/application/use_cases/search_documents.dart`).
The UI only offers search after a library opens and only scopes to its current
document, so both failures indicate stale caller state.

The scope selection and empty-query short circuit are covered in
`test/application/use_cases_test.dart`. Streaming without warming or leaking
the reading cache is covered in `test/application/read_document_cache_test.dart`.
The same use-case suite proves that a newer query prevents an older scan from
opening its next file.

## Transition

Progressive search and interruption inside source IO or parsing require richer
ports later. The
use case remains the owner of scope because “this document” and “this library”
are application choices; an index is responsible only for finding occurrences
within the documents it receives.
