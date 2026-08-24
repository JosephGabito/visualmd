# SearchDocuments

## Purpose and boundary

`SearchDocuments` chooses the documents in scope and delegates matching
through the [Document Search Port](06-document-search-port.md)
(`lib/application/use_cases/search_documents.dart`). It searches either
the whole open `Library` or one `DocumentId`; it does not parse Markdown,
match strings, construct excerpts, or render results.

## Present wiring

`execute(text, within:)` returns immediately for an empty field, then reads the
current library through `LibraryRepository` (`lib/application/use_cases/search_documents.dart`).
Without `within`, every document is handed to the search port in shelf order
(`lib/application/use_cases/search_documents.dart`). With an id, the use case resolves exactly that document and hands
the adapter a one-item iterable (`lib/application/use_cases/search_documents.dart`).

The composition root constructs one instance from the session repository and
the literal search adapter, then injects it into `ReaderController`
(`lib/main.dart`, `lib/main.dart`).

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

One stateless, `const` use-case instance lives for the application session.
The adapter behind it may cache prepared text; that state is outside this ring.

## Failure and recovery

No open library throws `NoLibraryOpen`; a scoped id absent from the current
library throws `DocumentNotFound` (`lib/application/use_cases/search_documents.dart`).
The UI only offers search after a library opens and only scopes to its current
document, so both failures indicate stale caller state.

The scope selection and empty-query short circuit are covered in
`test/application/use_cases_test.dart`.

## Transition

Progressive or cancellable search may require a richer return shape later. The
use case remains the owner of scope because “this document” and “this library”
are application choices; an index is responsible only for finding occurrences
within the documents it receives.
