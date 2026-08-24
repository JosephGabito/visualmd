# Document Source Identity

## Purpose and boundary

`DocumentSourceId` answers one question: did two scans describe the same
physical markdown? It is an opaque equality value in the domain ring. The
domain neither parses its value nor assumes that it is a filesystem path
(`lib/domain/library/document_source_id.dart`).

This identity is distinct from `DocumentId`. `DocumentId` scopes navigation
inside the session; source identity recognizes the same physical input across
two ways of offering it.

## Present wiring

A `Document` may carry a source id. The value is optional because not every
platform exposes enough information to establish physical identity
(`lib/domain/library/document.dart`). Folder scanners attach the value to
`FileEntry`, and `LibraryBuilder` preserves it when constructing the document
(`lib/domain/library/library_builder.dart`, `lib/domain/library/library_builder.dart`).

`Library.findBySource` walks standalone markdowns and folder documents through
the aggregate's normal document traversal. It compares ids only; it never
interprets their strings (`lib/domain/library/library.dart`).

## Inputs and outputs

| Input | Output |
|-------|--------|
| non-empty opaque string | `DocumentSourceId` |
| two ids | equality and matching hashes |
| `Library.findBySource(id)` | the existing document, or `null` |

## Events

None. Source identity is a value used by an application decision, not an
event-producing entity.

## Lifecycle

Infrastructure creates the id while scanning. It lives with the immutable
`Document` for that session and is discarded with the in-memory library.

The local scanner test proves that a directory scan and a direct scan of the
same file produce equal identities
(`test/infrastructure/local_folder_scanner_test.dart`).

## Failure and recovery

An empty value is rejected by assertion in checked builds. Absence is modeled
as `null`, not as a guessed filename. Callers may still use session identity,
but they cannot claim physical-path equality without this value.

## Transition

Equality is the complete domain meaning. Local paths and browser-handle
identities are adapter details, while workspace source identity and platform
access grants are stored separately. Keeping consumers from parsing the value
allows those platform representations to evolve without changing reconciliation.
