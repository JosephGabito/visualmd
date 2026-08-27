# Library Mutations

## Purpose and boundary

Six use cases change the open library: `AddFolder`, `EnrichFolderTitles`,
`AddMarkdown`, `RemoveFolder`, `RemoveMarkdown`, and `MoveFolder`. They coordinate the ports
that scan sources, store the in-memory library, and keep the workspace document
in step. The domain aggregate remains responsible for identity and ordering.
None of these use cases imports Flutter or a platform package
(`lib/application/use_cases/add_folder.dart`,
`lib/application/use_cases/enrich_folder_titles.dart`,
`lib/application/use_cases/add_markdown.dart`,
`lib/application/use_cases/remove_folder.dart`,
`lib/application/use_cases/remove_markdown.dart`,
`lib/application/use_cases/move_folder.dart`).

All five share `LibraryMutationQueue`. This is the application-level atomicity
boundary: asynchronous scans cannot commit in completion order when the user
made the requests in a different order
(`lib/application/library_mutation_queue.dart`).

## Present wiring

`AddFolder.execute` runs inside the queue. On a metadata-capable platform it
discovers paths and physical identities without opening document bytes, turns
the opaque ref id into a domain `LibraryRootId`, reads the current aggregate,
and builds one root. Before saving, it matches the root's physical source ids
against standalone markdowns. Matches move out of the standalone collection
and surface as the adapted folder document
(`lib/application/use_cases/add_folder.dart`). The result also carries
the next document to read and says whether the root identity was already
present. A deferred-title token says that filename labels are the first shelf
snapshot and authored headings can be enriched later
(`lib/application/use_cases/add_folder.dart`).

`EnrichFolderTitles` performs those source reads outside the mutation queue,
then re-enters the queue to apply only title changes whose document and physical
source identity still exist. It never changes folder membership, so a file
removed while IO was in flight cannot be resurrected. The controller also
fences each folder generation; removing or reopening a root makes its older
title result stale (`lib/application/use_cases/enrich_folder_titles.dart`,
`lib/api/reader_controller.dart`).

That result distinguishes three interface behaviours. An absorbed standalone
reopens under the folder identity and expands the tree to its new path.
Otherwise a new root opens its natural first document but stays minimized. A
refresh keeps a surviving relative selection, falls back when it disappeared,
and leaves another root's reading alone
(`lib/api/reader_controller.dart`).

`AddMarkdown` returns a physical-source match without duplicating it, including
the folder root that contains the document. A new source joins the standalone
collection and is saved. Its full contract is [AddMarkdown](07-add-markdown.md).

`RemoveFolder.execute` is also queued. Unknown ids leave the library unchanged.
When the selected root is removed, it chooses the root that slides into that
index, searches forward for a readable root, then walks backward. If no folder
document remains, the first standalone markdown becomes active. The folder on
disk is untouched (`lib/application/use_cases/remove_folder.dart`).

`RemoveMarkdown.execute` removes only from the aggregate's standalone
collection. If that document was selected, it hands reading to the next
standalone row, then the previous row, then the library's opening folder
document. Unknown ids leave the library unchanged, and no filesystem port
exists in the use case (`lib/application/use_cases/remove_markdown.dart`).

`MoveFolder.execute` asks the aggregate to move one root and saves only when
the aggregate changed (`lib/application/use_cases/move_folder.dart`). It
passes the selected document to workspace synchronization so arranging roots
does not change what is being read.

The queue chains each operation from the previous tail. Its private tail
absorbs an error only so later mutations can continue; the operation returned
to its caller still completes with that error
(`lib/application/library_mutation_queue.dart`).

## Inputs and outputs

| Use case | Input | Output |
|----------|-------|--------|
| `AddFolder` | `FolderRef`, optional selected document and insertion index | `AddedFolder(library, root, refreshed, adaptedDocument, nextDocument, deferredTitles)` |
| `EnrichFolderTitles` | deferred scan plus optional currency fence | updated `Library` and changed document identities, or `null` when stale |
| `AddMarkdown` | `MarkdownRef`, optional insertion index | `AddedMarkdown(library, document, containingRoot, added)` |
| `RemoveFolder` | `LibraryRootId`, optional selected `DocumentId` | `RemovedFolder(library, nextDocument)` |
| `RemoveMarkdown` | standalone `DocumentId`, optional selected `DocumentId` | `RemovedMarkdown(library, nextDocument)` |
| `MoveFolder` | `LibraryRootId`, destination index, optional selected document | updated `Library` |

All repository writes replace one immutable aggregate. The repository is never
asked to merge partial roots (`lib/application/ports/library_repository.dart`).

## Events

None today. The plugin roadmap identifies these completed mutations as natural
places for events because subscribers should only observe state that has been
committed successfully.

## Lifecycle

The composition root creates one shared reader state, one mutation queue, and
one instance of each use case, then gives them to `ReaderController`. The
controller publishes the metadata shelf before it opens the selected document,
then schedules title enrichment without keeping the opening spinner alive
(`lib/main.dart`, `lib/main.dart`). The live `Library` remains an in-memory
projection. When a workspace is bound to a writable file, successful mutations
also update that document through `WorkspaceMutationCommitter`, allowing the
library to be restored through [Workspace Lifecycle](09-workspace-lifecycle.md).

The controlled-scanner test proves rapid adds begin and commit in invocation
order. Focused tests also prove that a later containing folder removes its
standalone source, that the metadata shelf appears while source reads are
blocked, and that deferred titles cannot resurrect a deleted file
(`test/application/use_cases_test.dart`,
`test/api/reader_controller_library_test.dart`).

## Failure and recovery

- Metadata-scan failures propagate from either add use case; no aggregate is
  saved before a complete path snapshot has been built.
- Deferred title failures leave lossless filename labels in place and do not
  turn a successfully opened folder into an error state.
- A workspace synchronization or file-write failure stops the mutation before
  the replacement `Library` is saved.
- An unknown remove or move leaves the aggregate unchanged, making stale UI
  intent harmless (`lib/application/use_cases/remove_folder.dart`,
  `lib/application/use_cases/remove_markdown.dart`,
  `lib/domain/library/library.dart`).
- Removing either final source keeps the other collection. The controller
  returns to welcome only when both collections are empty
  (`lib/api/reader_controller.dart`).
- The queue continues after failure while preserving the error for the caller
  (`lib/application/library_mutation_queue.dart`).

## Transition

Workspace persistence already records membership and order, while platform
adapters retain or reacquire the handles needed to read those sources. Scan
progress is still absent. If measurements show that the metadata walk itself
needs it, a progress port can report that bounded phase without weakening the
serialized commit boundary.
