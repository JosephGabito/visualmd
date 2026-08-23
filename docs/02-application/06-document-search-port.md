# Document Search Port

## Purpose and boundary

`DocumentSearch` is the application-owned contract for finding a literal in
the visible text of domain documents
(`lib/application/ports/document_search.dart:4-13`). The application names the
need; infrastructure may satisfy it with a scan, index, or platform service.
The port owns none of those implementation choices.

## Present wiring

`find(query, documents)` receives a validated `SearchQuery` and an iterable of
`Document`s, returning grouped domain results
(`lib/application/ports/document_search.dart:8-12`). The only production
implementation is [LiteralDocumentSearch](../03-infrastructure/search/01-literal-document-search.md).

`SearchDocuments` calls the port after choosing current-document or library
scope (`lib/application/use_cases/search_documents.dart:19-33`). The composition
root supplies the adapter to `SearchDocuments` (`lib/main.dart:57-61`).

## Inputs and outputs

| Direction | Type | Contract |
|-----------|------|----------|
| In | `SearchQuery` | non-empty and literal, never executable syntax |
| In | `Iterable<Document>` | already scoped and ordered by the application |
| Out | `Future<List<DocumentSearchResult>>` | documents without matches omitted; offsets address visible text |

The future keeps indexing and worker-based adapters possible without changing
callers, even though the present matcher is local.

## Events

None. Ports answer application needs; they do not publish domain events.

## Lifecycle

The port implementation is constructed once in `main.dart` and retained by
`SearchDocuments`. The interface makes no cache or disposal promise.

## Failure and recovery

The current port defines no expected exception. A valid query over valid domain
documents returns zero or more results. Unexpected adapter failures propagate
to the caller rather than being presented as a complete set of zero results.

## Transition

An index may replace the scan when measurements show that libraries need it.
That adapter would preserve case-insensitive literal semantics and visible-text
offsets. A different search meaning belongs in an explicit domain query option,
not in an implementation swap.
