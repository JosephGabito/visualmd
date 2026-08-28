# Reader Controller

## Purpose and boundary

`ReaderController` is the API ring's state owner. Widgets read its fields and
emit intent through its methods; the controller calls application use cases
and never scans a folder or writes a file itself
(`lib/api/reader_controller.dart`).

Its injected source operations are `AddFolder`, `EnrichFolderTitles`,
`AddMarkdown`, `RemoveFolder`, `RemoveMarkdown`, and `MoveFolder`. Reading, searching, and external-source
refresh remain separate use cases. Folder
picking, the sample ref, theme registry, restored preferences and the
preference writer are also injected
(`lib/api/reader_controller.dart`).

## Present wiring

`addFolder` counts outstanding requests so the busy state remains true across
rapid drops. A successful new root opens its natural first document. A refresh
preserves a surviving selection in that root, falls back when the selected
path disappeared, and leaves another root's reading alone. If the folder
absorbs an open standalone markdown, the controller opens its folder-scoped
identity and requests that the tree expand to that document
(`lib/api/reader_controller.dart`). The application queue beneath this
method owns mutation order; the counter owns only interface state.

When a folder or restored workspace carries deferred titles, the controller
publishes the filename shelf before opening the selected document. It then
schedules title enrichment under a per-root generation. Removing, reopening,
replacing the workspace, or disposing the controller invalidates older work;
a title-read failure quietly keeps the lossless filename label
(`lib/api/reader_controller.dart`).

`addMarkdown` opens a new standalone source immediately. When that physical
source is already in a folder, it opens the existing folder document and sends
the same expand request (`lib/api/reader_controller.dart`).

`pickAndAddFolder` obtains a ref and follows the same path. The sample does too
(`lib/api/reader_controller.dart`). The composition root routes folder
and direct-markdown streams independently
(`lib/main.dart`).

`removeFolder` passes the current selection into the use case, maps an empty
aggregate back to the welcome state, and reads the deterministic neighbor only
when the removed root owned the page (`lib/api/reader_controller.dart`).
`removeMarkdown` does the same for one standalone identity, leaving folder
roots untouched and moving reading only when that standalone document was
active (`lib/api/reader_controller.dart`). `moveFolder` replaces the
aggregate but intentionally leaves `reading` unchanged
(`lib/api/reader_controller.dart`).

`openDocument` skips an already-open identity. Search delegates scope to
`SearchDocuments` without retaining query state. Library mutations align both
the reading cache and the search projection index: changed identities are
invalidated, removed identities are released, and a new workspace clears both
(`lib/api/reader_controller.dart`).

Relative links are resolved from the current `DocumentId`. Because resolution
keeps its `LibraryRootId`, the candidate lookup cannot cross into a second root
with the same path (`lib/api/reader_controller.dart`,
`lib/domain/library/document_id.dart`). Schemed URLs remain external except
for executable `javascript`, `data` and `vbscript` payloads, which resolve to
no action and never reach a platform opener. Hash-only links remain anchors,
including the numbered suffix assigned to a duplicate heading. A relative
document may carry a fragment; the
controller resolves the path within the current root and keeps the fragment on
the resulting `DocumentLink`. Empty and missing targets remain `null` rather
than becoming accidental navigation (`lib/api/reader_controller.dart`).

## Preferences

The same controller owns transient panel, typography and theme choices. Theme,
reading mode, text size, paragraph marking, shelf width and outline width each
have a named storage key (`lib/api/reader_controller.dart`,
`lib/api/reader_controller.dart`). Previewing a panel resize notifies
continuously; persistence happens only on commit or reset.

The platform stores opaque strings. It never needs to know what a theme choice
or panel width means (`lib/main.dart`, `lib/main.dart`). Folder membership and
root order are deliberately not preferences yet.

## Inputs and outputs

| Input | Effect |
|-------|--------|
| `FolderRef` | add or refresh one session root |
| `MarkdownRef` | add a standalone document or open its folder match |
| `LibraryRootId` | remove or arrange one root |
| standalone `DocumentId` | remove one direct source from the session |
| `DocumentId` | read a scoped document |
| href | return `AnchorLink`, `DocumentLink`, `ExternalLink`, or `null` |
| reader choice | notify immediately and persist when appropriate |

Outputs are state replacement plus `notifyListeners()`. `ReaderScreen` rebuilds
through `ListenableBuilder` (`lib/api/screens/reader_screen.dart`,
`lib/api/screens/reader_screen.dart`).

## Events

The controller subscribes to committed `SourceSyncEvent` values. A successful
refresh replaces the Library, rereads the active document when its bytes or
identity changed, increments `contentRevision`, and keeps the selected identity
when it survived. The same changed-document set invalidates only those retained
search projections (`lib/api/reader_controller.dart`). Widgets use that
revision to refresh transient projections such as an open search.

## Lifecycle

One controller lives for the app process and disposes its source subscription,
coordinator, and deferred-title generations with itself
(`lib/api/reader_controller.dart`). Web launch options may add the sample
root or change theme and reading parameters before the first frame
(`lib/main.dart`). Startup creates an unbound workspace; opening a
saved workspace is an explicit reader action.

The controller-level tests prove the filename shelf is visible while its
opening source is still blocked, as well as both directions of physical-source adaptation:
a direct duplicate expands its existing root to the document, while a later
containing folder removes the open standalone and reopens it under the folder
identity
(`test/api/reader_controller_library_test.dart`).

## Failure and recovery

Source-add errors become a short message while the previous aggregate remains
available. The outstanding-request counter is decremented in `finally`, so one
failed rapid drop cannot leave the busy state stuck
(`lib/api/reader_controller.dart`). A later successful request clears
an earlier error; `clearError` gives the occupied-reader notice an explicit
dismiss action (`lib/api/reader_controller.dart`).

A watcher or reread failure uses the same persistent occupied-reader error
surface instead of disappearing behind the welcome screen. The last good
Library remains readable, and a later successful synchronization clears only
that synchronization error (`lib/api/reader_controller.dart`).

Shelf-generated remove and move ids are safe no-ops if stale. A missing
document still surfaces as `DocumentNotFound`; the shelf can only offer ids
from the current aggregate.

## Transition

Workspace restoration now supplies a complete restored session through use
cases, while the controller remains unaware of paths, bookmarks, and browser
handles. Link resolution may move into a use case if callers beyond the reader
screen need it; its root-scoped rule already lives in the domain.
