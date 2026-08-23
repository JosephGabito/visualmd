# RemoveMarkdown

## Purpose and boundary

`RemoveMarkdown` removes one directly opened document from the session. It
does not remove a file from disk and cannot do so: its dependencies are the
library repository, shared mutation queue, and workspace committer
(`lib/application/use_cases/remove_markdown.dart:18-29`).

## Present wiring

`execute` reads the current aggregate inside the shared mutation queue. An id
outside `Library.markdowns` returns the current aggregate unchanged. A present
id is removed through the domain operation, synchronized with the workspace,
and saved (`lib/application/use_cases/remove_markdown.dart:31-41`, `:56-61`).

Reading handoff happens only when the removed id was selected. The document
that slides into the same standalone index wins; at the end of the list that
becomes the preceding document. When no standalone documents remain, the
aggregate's opening folder document is used
(`lib/application/use_cases/remove_markdown.dart:42-54`).

## Inputs and outputs

| Input | Output |
|-------|--------|
| standalone `DocumentId` | `RemovedMarkdown` with the replacement `Library` |
| optional selected `DocumentId` | `nextDocument` only when reading must move |
| unknown or folder-scoped id | unchanged library and no next document |

## Events

None today. If a standalone-markdown-removed event gains a subscriber, it
belongs after the workspace and library mutation succeeds.

## Lifecycle

The composition root creates one instance for the process and gives it the
same mutation queue and workspace committer as both add paths and folder
mutations (`lib/main.dart:64-105`). The controller calls it only from shelf
intent (`lib/api/reader_controller.dart:362-378`).

## Failure and recovery

Workspace or repository failures propagate to the controller. A stale id
leaves the library unchanged. Removing the final source produces an empty
aggregate; the controller maps that to the welcome state. Focused tests cover
next, previous, folder, and empty-library handoff
(`test/application/use_cases_test.dart:328-385`,
`test/api/reader_controller_library_test.dart:154-205`).

## Transition

A successful removal is also written into the current workspace through
`WorkspaceMutationCommitter`; machine-local handles remain an infrastructure
concern. The use case removes session membership only. Disk deletion is a
different capability and is outside this boundary.
