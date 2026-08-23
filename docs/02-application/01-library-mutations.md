# Library Mutations

## Purpose and boundary

Five use cases change the open library: `AddFolder`, `AddMarkdown`,
`RemoveFolder`, `RemoveMarkdown`, and `MoveFolder`. They coordinate the ports
that scan sources, store the in-memory library, and keep the workspace document
in step. The domain aggregate remains responsible for identity and ordering.
None of these use cases imports Flutter or a platform package
(`lib/application/use_cases/add_folder.dart:33-47`,
`lib/application/use_cases/add_markdown.dart:28-42`,
`lib/application/use_cases/remove_folder.dart:19-30`,
`lib/application/use_cases/remove_markdown.dart:18-29`,
`lib/application/use_cases/move_folder.dart:11-22`).

All five share `LibraryMutationQueue`. This is the application-level atomicity
boundary: asynchronous scans cannot commit in completion order when the user
made the requests in a different order
(`lib/application/library_mutation_queue.dart:1-11`).

## Present wiring

`AddFolder.execute` runs inside the queue. It scans the opaque `FolderRef`,
turns that ref id into a domain `LibraryRootId`, reads the current aggregate,
and builds one root. Before saving, it matches the root's physical source ids
against standalone markdowns. Matches move out of the standalone collection
and surface as the adapted folder document
(`lib/application/use_cases/add_folder.dart:49-85`). The result also carries
the next document to read and says whether the root identity was already
present (`lib/application/use_cases/add_folder.dart:14-30`, `:86-103`).

That result distinguishes three interface behaviours. An absorbed standalone
reopens under the folder identity and expands the tree to its new path.
Otherwise a new root opens its natural first document but stays minimized. A
refresh keeps a surviving relative selection, falls back when it disappeared,
and leaves another root's reading alone
(`lib/api/reader_controller.dart:158-180`).

`AddMarkdown` returns a physical-source match without duplicating it, including
the folder root that contains the document. A new source joins the standalone
collection and is saved. Its full contract is [AddMarkdown](07-add-markdown.md).

`RemoveFolder.execute` is also queued. Unknown ids leave the library unchanged.
When the selected root is removed, it chooses the root that slides into that
index, searches forward for a readable root, then walks backward. If no folder
document remains, the first standalone markdown becomes active. The folder on
disk is untouched (`lib/application/use_cases/remove_folder.dart:32-70`).

`RemoveMarkdown.execute` removes only from the aggregate's standalone
collection. If that document was selected, it hands reading to the next
standalone row, then the previous row, then the library's opening folder
document. Unknown ids leave the library unchanged, and no filesystem port
exists in the use case (`lib/application/use_cases/remove_markdown.dart:31-61`).

`MoveFolder.execute` asks the aggregate to move one root and saves only when
the aggregate changed (`lib/application/use_cases/move_folder.dart:24-35`). It
passes the selected document to workspace synchronization so arranging roots
does not change what is being read.

The queue chains each operation from the previous tail. Its private tail
absorbs an error only so later mutations can continue; the operation returned
to its caller still completes with that error
(`lib/application/library_mutation_queue.dart:4-11`).

## Inputs and outputs

| Use case | Input | Output |
|----------|-------|--------|
| `AddFolder` | `FolderRef`, optional selected document and insertion index | `AddedFolder(library, root, refreshed, adaptedDocument, nextDocument)` |
| `AddMarkdown` | `MarkdownRef`, optional insertion index | `AddedMarkdown(library, document, containingRoot, added)` |
| `RemoveFolder` | `LibraryRootId`, optional selected `DocumentId` | `RemovedFolder(library, nextDocument)` |
| `RemoveMarkdown` | standalone `DocumentId`, optional selected `DocumentId` | `RemovedMarkdown(library, nextDocument)` |
| `MoveFolder` | `LibraryRootId`, destination index, optional selected document | updated `Library` |

All repository writes replace one immutable aggregate. The repository is never
asked to merge partial roots (`lib/application/ports/library_repository.dart:3-7`).

## Events

None today. The plugin roadmap identifies these completed mutations as natural
places for events because subscribers should only observe state that has been
committed successfully.

## Lifecycle

The composition root creates one shared reader state, one mutation queue, and
one instance of each use case, then gives them to `ReaderController`
(`lib/main.dart:46-110`, `:175-208`). The live `Library` remains an in-memory
projection. When a workspace is bound to a writable file, successful mutations
also update that document through `WorkspaceMutationCommitter`, allowing the
library to be restored through [Workspace Lifecycle](09-workspace-lifecycle.md).

The controlled-scanner test proves rapid adds begin and commit in invocation
order. Focused tests also prove that a later containing folder removes its
standalone source and returns the folder-scoped document
(`test/application/use_cases_test.dart:231-298`).

## Failure and recovery

- Scanner failures propagate from either add use case; no aggregate is saved before a
  complete scan has been built.
- A workspace synchronization or file-write failure stops the mutation before
  the replacement `Library` is saved.
- An unknown remove or move leaves the aggregate unchanged, making stale UI
  intent harmless (`lib/application/use_cases/remove_folder.dart:34-38`,
  `lib/application/use_cases/remove_markdown.dart:33-39`,
  `lib/domain/library/library.dart:102-115`).
- Removing either final source keeps the other collection. The controller
  returns to welcome only when both collections are empty
  (`lib/api/reader_controller.dart:180-204`).
- The queue continues after failure while preserving the error for the caller
  (`lib/application/library_mutation_queue.dart:7-10`).

## Transition

Workspace persistence already records membership and order, while platform
adapters retain or reacquire the handles needed to read those sources. Scan
progress is still absent. If measurements show that large folders need it, a
progress port can report the active scan without weakening the serialized
commit boundary.
