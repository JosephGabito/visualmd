# Source Synchronization

## Purpose and boundary

Source synchronization keeps an open Library aligned with Markdown changed by
another process. The application owns ordering, coalescing and the atomic
Library replacement; platform adapters own only the signal and the fresh read.
The contract is expressed by `SourceChangeMonitor` and
`FolderDocumentScanner` (`lib/application/ports/source_change_monitor.dart`,
`lib/application/ports/folder_document_scanner.dart`).

Platform events are invalidations, never file contents. This matters because an
older event can arrive late: the application rereads after the event instead of
allowing stale bytes to travel through the event stream
(`lib/application/ports/source_change_monitor.dart`).

## Present wiring

`SourceWatchCoordinator` owns one watch per open folder or standalone Markdown,
waits for 250 milliseconds of quiet, merges repeated folder paths, and lets a
full rescan supersede targeted paths (`lib/application/source_watch_coordinator.dart`,
`lib/application/source_watch_coordinator.dart`). When a source is removed, absorbed, or replaced, its watch is
cancelled (`lib/application/source_watch_coordinator.dart`).

`RefreshSource` then runs inside the same `LibraryMutationQueue` as manual
source changes. A targeted folder change reads only its invalidated documents
to refresh title metadata, then mutates only their folder paths; a coarse event
rebuilds the metadata-only root; a standalone change replaces that document
under the same identity
(`lib/application/use_cases/refresh_source.dart`). A cancelled watch is checked both before and after its asynchronous
read, so it cannot commit after a source has been rebound
(`lib/application/use_cases/refresh_source.dart`).

The targeted path uses `DocumentOutline.titleOf` rather than constructing a
complete outline. Unchanged sibling branches keep object identity, and only a
directory whose direct documents or subfolders changed is naturally resorted
(`lib/domain/library/folder.dart`,
`lib/application/use_cases/refresh_source.dart`).

## Inputs and outputs

| Input | Application action |
|-------|--------------------|
| `FolderDocumentsInvalidated` | reread the named relative Markdown paths |
| `FolderRescanRequested` | rescan and compare the complete root |
| `MarkdownInvalidated` | reread one standalone source |
| `SourceWatchFailed` | report degraded synchronization without changing content |

`RefreshedSource` returns the new Library, the surviving active document, and
the document identities invalidated by the event
(`lib/application/use_cases/refresh_source.dart`). The coordinator emits
either `SourceSynchronized` or `SourceSynchronizationFailed` to the API ring
(`lib/application/source_watch_coordinator.dart`).

## Events

These are application synchronization events, not domain history. The success
event carries a committed snapshot; the failure event carries a display name
and reason. Neither changes the Library by itself.

## Lifecycle

The composition root creates one coordinator for the reader. Adding a source
starts its watch; opening a Workspace replaces the complete watch set; removing
or absorbing a source releases its watch. Disposing the controller closes every
subscription and timer (`lib/application/source_watch_coordinator.dart`,
`lib/application/source_watch_coordinator.dart`).

After a committed refresh, `ReaderController` removes those identities from
the `ReadDocument` LRU before reopening the active document
(`lib/api/reader_controller.dart`). A full rescan invalidates both the old and
new root's ids even when paths and source identities match, because lightweight
metadata cannot prove that the underlying bytes stayed equal.

The coordinator serializes refreshes per source. If another invalidation arrives
while a read is running, it records a second pass and rereads after the first
commit rather than dropping the newer signal
(`lib/application/source_watch_coordinator.dart`).

## Failure and recovery

A read or watcher failure leaves the last good Library intact and becomes a
visible controller error. A later successful refresh clears that synchronization
error (`lib/api/reader_controller.dart`). A deleted selected document
moves reading first to the same root's opening document, then to the Library's
opening document (`lib/application/use_cases/refresh_source.dart`).

The recurrence tests cover quiet-period coalescing, invalidation during a
running refresh, and cancellation before commit
(`test/application/source_refresh_test.dart`). Controller and widget tests cover
active identity, outline/search replacement, and preserved reading position
(`test/api/reader_controller_source_sync_test.dart`,
`test/presentation/reading_pane_refresh_test.dart`).
Domain tests additionally prove targeted creation, deletion, natural ordering,
empty-branch pruning, and structural sharing of an untouched sibling
(`test/domain/library_builder_test.dart`).

## Transition

The invalidation contract is deliberately independent of a particular observer.
A future platform can provide a stronger native event source without changing
`RefreshSource`, while a future content index can react to the same committed
`changedDocuments` set.
