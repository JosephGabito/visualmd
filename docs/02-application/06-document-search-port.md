# Document Search Port

## Purpose and boundary

`DocumentSearch` is the application-owned contract for finding a literal in
the visible text of domain documents
(`lib/application/ports/document_search.dart`). The application names the
need; infrastructure may satisfy it with a scan, index, or platform service.
The port owns none of those implementation choices.

## Present wiring

`find(query, documents)` receives a validated `SearchQuery` and an iterable of
`Document`s, returning grouped domain results
(`lib/application/ports/document_search.dart`). The only production
implementation is [LiteralDocumentSearch](../03-infrastructure/search/01-literal-document-search.md).

`SearchDocuments` calls the port after choosing current-document or library
scope (`lib/application/use_cases/search_documents.dart`). The composition
root supplies the adapter to `SearchDocuments` (`lib/main.dart`).

## Inputs and outputs

| Direction | Type | Contract |
|-----------|------|----------|
| In | `SearchQuery` | non-empty and literal, never executable syntax |
| In | `Iterable<Document>` | already scoped and ordered by the application |
| Out | `Future<List<DocumentSearchResult>>` | documents without matches omitted; offsets address visible text |

The future keeps indexing and worker-based adapters possible without changing
callers, even though the present matcher is local.

`DocumentSearchIndex` is the optional retained-projection capability. Its
`contains` query lets the application avoid source IO on a hit. `invalidate`
removes changed identities, `retain` releases documents outside the current
library, and `clear` ends the session (`lib/application/ports/document_search.dart`).

## Events

None. Ports answer application needs; they do not publish domain events.

## Lifecycle

The port implementation is constructed once in `main.dart` and retained by
`SearchDocuments`. A plain `DocumentSearch` remains stateless from the
application's perspective. A `DocumentSearchIndex` explicitly owns a derived
cache and its invalidation lifecycle; it never makes source text part of the
library model.

## Failure and recovery

The current port defines no expected exception. A valid query over valid domain
documents returns zero or more results. Unexpected adapter failures propagate
to the caller rather than being presented as a complete set of zero results.

## Transition

The current index removes repeated source IO and parsing, but matching is still
a linear visible-text scan. A token or n-gram index may replace that scan when
the benchmark justifies its memory and update cost. It must preserve
case-insensitive literal semantics and visible-text offsets. A different search
meaning belongs in an explicit domain query option, not an implementation swap.
