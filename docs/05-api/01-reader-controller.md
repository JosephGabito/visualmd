# Reader Controller

## Purpose and boundary

`ReaderController` is the API ring's state owner. Widgets read its fields and
emit intent through its methods; the controller calls application use cases
and never scans a folder or writes a file itself
(`lib/api/reader_controller.dart:41-75`).

Its injected source operations are `AddFolder`, `AddMarkdown`, `RemoveFolder`,
`RemoveMarkdown`, and `MoveFolder`. Reading and searching remain separate use cases. Folder
picking, the sample ref, theme registry, restored preferences and the
preference writer are also injected
(`lib/api/reader_controller.dart:45-84`).

## Present wiring

`addFolder` counts outstanding requests so the busy state remains true across
rapid drops. A successful new root opens its natural first document. A refresh
preserves a surviving selection in that root, falls back when the selected
path disappeared, and leaves another root's reading alone. If the folder
absorbs an open standalone markdown, the controller opens its folder-scoped
identity and requests that the tree expand to that document
(`lib/api/reader_controller.dart:158-190`). The application queue beneath this
method owns mutation order; the counter owns only interface state.

`addMarkdown` opens a new standalone source immediately. When that physical
source is already in a folder, it opens the existing folder document and sends
the same expand request (`lib/api/reader_controller.dart:191-218`).

`pickAndAddFolder` obtains a ref and follows the same path. The sample does too
(`lib/api/reader_controller.dart:219-227`). The composition root routes folder
and direct-markdown streams independently
(`lib/main.dart:201-203`).

`removeFolder` passes the current selection into the use case, maps an empty
aggregate back to the welcome state, and reads the deterministic neighbor only
when the removed root owned the page (`lib/api/reader_controller.dart:180-191`).
`removeMarkdown` does the same for one standalone identity, leaving folder
roots untouched and moving reading only when that standalone document was
active (`lib/api/reader_controller.dart:193-204`). `moveFolder` replaces the
aggregate but intentionally leaves `reading` unchanged
(`lib/api/reader_controller.dart:206-209`).

`openDocument` skips an already-open identity. Search delegates scope to
`SearchDocuments` without retaining query state
(`lib/api/reader_controller.dart:396-411`).

Relative links are resolved from the current `DocumentId`. Because resolution
keeps its `LibraryRootId`, the candidate lookup cannot cross into a second root
with the same path (`lib/api/reader_controller.dart:412-434`,
`lib/domain/library/document_id.dart:33-50`). Schemed URLs remain external and
hash-only links remain anchors.

## Preferences

The same controller owns transient panel, typography and theme choices. Theme,
text size, paragraph marking, shelf width and outline width each have a named
storage key (`lib/api/reader_controller.dart:88-102`,
`lib/api/reader_controller.dart:207-280`). Previewing a panel resize notifies
continuously; persistence happens only on commit or reset.

The platform stores opaque strings. It never needs to know what a theme choice
or panel width means (`lib/main.dart:64-79`, `:88-95`). Folder membership and
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
through `ListenableBuilder` (`lib/api/screens/reader_screen.dart:41-46`,
`:276-280`).

## Events

None. Folder and document lifecycle events eventually belong after successful
application commits, not in this controller. Preference persistence already
has the function-shaped seam a future event reactor would replace.

## Lifecycle

One controller lives for the app process. Web launch options may add the sample
root or change theme and reading parameters before the first frame
(`lib/main.dart:222-235`). Startup creates an unbound workspace; opening a
saved workspace is an explicit reader action.

The controller-level tests prove both directions of physical-source adaptation:
a direct duplicate expands its existing root to the document, while a later
containing folder removes the open standalone and reopens it under the folder
identity
(`test/api/reader_controller_library_test.dart:133-231`).

## Failure and recovery

Source-add errors become a short message while the previous aggregate remains
available. The outstanding-request counter is decremented in `finally`, so one
failed rapid drop cannot leave the busy state stuck
(`lib/api/reader_controller.dart:158-218`). A later successful request clears
an earlier error; `clearError` gives the occupied-reader notice an explicit
dismiss action (`lib/api/reader_controller.dart:443-447`).

Shelf-generated remove and move ids are safe no-ops if stale. A missing
document still surfaces as `DocumentNotFound`; the shelf can only offer ids
from the current aggregate.

## Transition

Workspace restoration now supplies a complete restored session through use
cases, while the controller remains unaware of paths, bookmarks, and browser
handles. Link resolution may move into a use case if callers beyond the reader
screen need it; its root-scoped rule already lives in the domain.
