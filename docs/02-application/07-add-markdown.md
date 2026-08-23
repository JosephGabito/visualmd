# AddMarkdown

## Purpose and boundary

`AddMarkdown` handles one markdown offered directly instead of through a
folder. It either adds a standalone document or resolves the offer to the same
physical document already in the session. It owns orchestration, not path
rules or file access (`lib/application/use_cases/add_markdown.dart:28-47`).

## Present wiring

The use case scans a `MarkdownRef`, reads the current aggregate, and creates a
session-scoped `DocumentId` for a new standalone document. When the scanner
supplies source identity, lookup uses `Library.findBySource`; without one it
can only recognize the same application ref
(`lib/application/use_cases/add_markdown.dart:44-56`).

An existing match returns that exact `Document` without saving or duplicating
it. `containingRoot` is non-null only when the match belongs to a folder root;
the API uses that fact to expand the tree to the document
(`lib/application/use_cases/add_markdown.dart:57-64`). A new source becomes a
`Document`, joins `Library.markdowns`, and is saved through the repository
after its workspace membership is synchronized
(`lib/application/use_cases/add_markdown.dart:67-80`).

The `MarkdownScanner` port keeps platform handles outside the application.
`MarkdownRef` is identity plus display name; `ScannedMarkdown` is name, text,
and optional opaque physical identity
(`lib/application/ports/markdown_scanner.dart:3-33`).

## Inputs and outputs

| Input | Output |
|-------|--------|
| new `MarkdownRef` | `AddedMarkdown(added: true)` with the updated library |
| physical match in `Library.roots` | existing document and `containingRoot` |
| match already in `Library.markdowns` | existing document, no containing root |

## Events

None today. If a standalone-markdown-opened event gains a real subscriber, it
belongs after the workspace and library mutation succeeds.

## Lifecycle

The composition root creates one instance with the same
`LibraryMutationQueue` used by folder operations. Folder and markdown drops
therefore commit in invocation order (`lib/main.dart:64-105`).

Focused tests prove both the new-document and physical-folder-match branches
without a filesystem adapter (`test/application/use_cases_test.dart:152-218`).
The inverse transition is owned by `AddFolder`: dropping the containing folder
later removes the standalone entry and returns the folder-scoped document
(`lib/application/use_cases/add_folder.dart:63-85`).

## Failure and recovery

`MarkdownUnavailable` or a read failure propagates before any save. The
controller retains the previous aggregate, clears the busy count in `finally`,
and shows a concise open error (`lib/api/reader_controller.dart:191-212`).

## Transition

Standalone removal is the separate [RemoveMarkdown](08-remove-markdown.md)
use case. The split keeps source reconciliation here and session removal there;
neither turns Markdowns into a synthetic folder. `UpdateWorkspace` commits the
membership change after this use case succeeds, while machine-local handles
remain behind `WorkspaceSourceAccess`. See
[Workspace Lifecycle](09-workspace-lifecycle.md).
