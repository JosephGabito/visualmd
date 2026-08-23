# In-Memory Repository and Routing Scanner

## Purpose and boundary

Two small adapters connect application ports without touching a platform.

`InMemoryLibraryRepository` implements the `LibraryRepository` port: it is
where the current session `Library` lives between folder mutations saving it and
`ReadDocument` asking for it
(`lib/infrastructure/memory/in_memory_library_repository.dart:4-5`,
`lib/application/ports/library_repository.dart:3-7`).

`RoutingFolderScanner` implements the `FolderScanner` port over a list of
scanners so the use case sees one port while bundled and platform folders
are answered by different adapters
(`lib/infrastructure/routing_folder_scanner.dart:3-5`). See
[Ports](../../02-application/03-ports.md).

## Present wiring

**Repository.** `save` and `current` read one `Library?` from the shared
`InMemoryReaderState` (`lib/infrastructure/memory/in_memory_library_repository.dart:5-16`,
`lib/infrastructure/memory/in_memory_reader_state.dart:4-12`). Sharing that
state with the workspace session repository lets workspace restoration replace
both values as one operation. The port remains `Future`-typed, so callers do
not depend on memory being the storage mechanism.

**Routing.** `scan(ref)` tries each scanner in order and returns the first
result; a scanner that throws `FolderUnavailable` is skipped, and if every
scanner declines the router throws `FolderUnavailable` itself
(`lib/infrastructure/routing_folder_scanner.dart:10-20`). Routing is by
*declining*, not by inspecting the ref's id, so the router knows nothing
about id prefixes.

The composition root builds the list as `[SampleFolderScanner(), platform.folderScanner]`
(`lib/main.dart:47-60`): the sample scanner answers only its constant ref and
declines everything else (`lib/infrastructure/memory/sample_folder_scanner.dart:9-12`),
so a browser or local ref falls through to the platform scanner.

| Adapter | Port | Constructed at |
|---------|------|----------------|
| `InMemoryLibraryRepository` | `LibraryRepository` | `lib/main.dart:48-50` |
| `RoutingFolderScanner` | `FolderScanner` | `lib/main.dart:57-60` |

## Inputs and outputs

| Adapter | In | Out |
|---------|----|-----|
| repository `save` | `Library` | — |
| repository `current` | — | `Library?` (`null` before the first open) |
| router `scan` | `FolderRef` | `ScannedFolder` from the first scanner that accepts |
| router `scan` (error) | — | `FolderUnavailable(ref)` when none accepts |

## Events

None. The repository stores committed state; any later library event belongs
after the use case has completed that commit, so subscribers observe the same
library as `current()`.

## Lifecycle

Both are created once in `main()` and live for the process. The repository
holds exactly one aggregate; mutations replace that value while preserving
its ordered roots. The router's list is fixed at construction.

## Failure and recovery

- `ReadDocument` with no library saved yet gets `null` from `current()` and
  raises `NoLibraryOpen` (`lib/application/use_cases/read_document.dart:38-39`);
  the UI never calls it in that state.
- A scanner that throws anything other than `FolderUnavailable` is not
  skipped. That preserves the useful distinction between “this scanner does
  not own the ref” and “this scanner owns it but could not read the source.”
- The application tests use hand-written fakes for both ports rather than
  these adapters (`test/application/use_cases_test.dart:11-27`), which is the
  intended way to test use cases.

## Transition

Workspace persistence stores portable source descriptions and platform access
outside this repository, then rebuilds the library when a workspace opens. A
persistent parsed-library cache could still sit behind the same port later,
but current behavior prefers a fresh scan so the shelf reflects the source on
disk.
