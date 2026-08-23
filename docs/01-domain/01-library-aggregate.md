# Library Aggregate

## Purpose and boundary

`Library` is the aggregate for one reading session: directly opened markdowns
plus an ordered list of independently opened top-level folders. Both are
values inside the aggregate, not platform handles
(`lib/domain/library/library.dart:7-40`). Folder identity is an opaque
`LibraryRootId`; optional physical-file equality is an opaque
`DocumentSourceId` ([Document Source Identity](07-document-source-identity.md)).

Six types make up the library:

| Type | Role | Evidence |
|------|------|----------|
| `Library` | standalone markdowns, ordered roots and aggregate operations | `lib/domain/library/library.dart:7-120` |
| `LibraryRoot` | one named top-level folder and its tree | `lib/domain/library/library_root.dart:7-35` |
| `Folder` | one nested shelf of folders and documents | `lib/domain/library/folder.dart:6-40` |
| `Document` | markdown source, optional source identity and lazy outline | `lib/domain/library/document.dart:6-31` |
| `DocumentId` | root identity plus a relative path | `lib/domain/library/document_id.dart:3-60` |
| `DocumentSourceId` | opaque equality for one physical source | `lib/domain/library/document_source_id.dart:1-17` |

The boundary stops at what is on the shelf. Scanning is an application and
infrastructure concern; file filtering and nested order are the
[Shelving Rules](02-shelving-rules.md).

## Present wiring

Both collections are copied into unmodifiable lists. Duplicate folder ids,
duplicate standalone document ids, and a standalone scope colliding with a
folder root are rejected (`lib/domain/library/library.dart:12-36`). Documents
are yielded with standalone markdowns first, matching the shelf
(`lib/domain/library/library.dart:42-53`). `find` checks standalone identity and
then the owning root; `findBySource` compares optional physical identity across
both collections (`lib/domain/library/library.dart:55-74`).

`Library.addOrReplace` is the important identity rule. A new id appends; an
existing id replaces at its current index. `remove` drops only the named root,
`removeMarkdown` drops only the named standalone document, and `move` changes
only top-level order (`lib/domain/library/library.dart:76-117`). Nested folder
and document order is therefore untouched by arranging roots or removing a
standalone source.

Each `LibraryRoot` delegates counting and traversal to its `Folder`, rejects a
document id from another root, and chooses its root README before its first
document (`lib/domain/library/library_root.dart:18-34`).

`DocumentId` carries both `rootId` and its normalised relative path. Equality
and hashing use both fields, so `README.md` in two roots remains two documents
(`lib/domain/library/document_id.dart:8-16`, `:52-57`). Relative resolution
keeps the same root id while normalising `.`, `..`, leading `/`, separators,
and percent encoding (`lib/domain/library/document_id.dart:33-50`). A link can
reach the current root's README, never a same-named file in another root.

## Inputs and outputs

| Operation | Result |
|-----------|--------|
| `Library(roots:, markdowns:)` | immutable collections, or `ArgumentError` for identity collisions |
| `addOrReplace(root)` | append a new identity or refresh it in place |
| `addOrReplaceMarkdown(document)` | append or refresh one standalone identity |
| `remove(id)` | a new library without that root |
| `removeMarkdown(id)` | a new library without that standalone document |
| `move(id, index)` | a new library with the root moved to a bounded index |
| `find(DocumentId)` / `findBySource(id)` | the scoped or physical document, or `null` |
| `DocumentId.resolve(href)` | a new id inside the same root |

The two-root fixture proves that duplicate relative paths stay distinct and
that session order is preserved
(`test/application/use_cases_test.dart:104-124`). Move and folder handoff are
exercised together, while standalone removal covers next, previous and folder
fallback (`test/application/use_cases_test.dart:300-385`).

## Events

None. Aggregate operations return new values. If mutation events are added,
the application use case can publish them after the complete commit; the
domain value itself remains free of subscribers and side effects.

## Lifecycle

The session starts with `Library.empty()`. Every successful source mutation
creates a new aggregate and saves it; unchanged values are reused. Removing the
last source returns to the welcome view only when neither roots nor standalone
markdowns remain (`lib/api/reader_controller.dart:343-378`).

Document outlines remain lazy and are parsed once per `Document`
(`lib/domain/library/document.dart:20-26`). Refreshing a root creates new
documents only for that root.

## Failure and recovery

- An empty document path is rejected (`lib/domain/library/document_id.dart:12-16`).
- Duplicate or cross-collection identities are rejected at aggregate
  construction (`lib/domain/library/library.dart:17-35`).
- Looking up a missing root or document returns `null`; application use cases
  decide whether that is a no-op or a `DocumentNotFound`.
- Resolving above a root stops at that root; it never escapes into another
  folder (`test/domain/library_builder_test.dart:108-120`).

## Transition

`Library` remains the live, in-memory projection. Durable membership, order,
theme, and reading intent belong to the [Workspace Aggregate](08-workspace-aggregate.md),
which can be restored using fresh platform access. If measurements show that
document lookup is expensive in large libraries, an index keyed by the
already-scoped `DocumentId` can replace the linear walk without changing the
aggregate's public operations.
