# Workspace Lifecycle

## Purpose and boundary

A workspace document records which sources belong in a reading room, their
order, the selected theme, and the active document. The workspace lifecycle
turns that saved intent into the current `Library` and keeps later reading
actions synchronized with it. Application use cases order scans, file writes,
and in-memory commits; adapters provide dialogs, JSON, and platform handles.

## Present wiring

`CreateWorkspace` flushes a pending bound save, constructs an empty unbound
Workspace, and atomically replaces both in-memory projections
(`lib/application/use_cases/create_workspace.dart:29-42`). `OpenWorkspace`
selects and decodes a file before entering the shared mutation queue
(`lib/application/use_cases/open_workspace.dart:51-67`).

Restore scans every reachable folder and standalone Markdown into temporary
collections. Only expected unavailable-source failures are retained as missing;
an unexpected scanner failure aborts restoration
(`lib/application/use_cases/open_workspace.dart:69-91`,
`lib/application/use_cases/open_workspace.dart:95-130`). If a restored folder
contains a standalone source, the standalone membership is absorbed and the
active address follows the same physical document into the folder tree
(`lib/application/use_cases/open_workspace.dart:98-116`).

The Library and WorkspaceSession replace together only after restoration and
normalization succeed (`lib/application/use_cases/open_workspace.dart:132-163`).
Structural changes write first when a bound file supports automatic writes;
theme and active-document changes are coalesced by autosave
(`lib/application/use_cases/update_workspace.dart:178-215`).

## Inputs and outputs

| Use case | Input | Output |
|----------|-------|--------|
| `CreateWorkspace` | current theme | unbound dirty `WorkspaceSession` |
| `OpenWorkspace` | selected workspace file | restored session, Library, active Document |
| `SaveWorkspace` | current session | same identity bound and clean |
| `SaveWorkspaceAs` | current session and new file | new identity bound and clean |
| `ReconnectWorkspaceSource` | missing source identity | platform ref plus saved insertion index |
| `UpdateWorkspace` | successful Library mutation or reading choice | synchronized session |

The ports are `WorkspaceFiles`, `WorkspaceCodec`, `WorkspaceSourceAccess`,
`WorkspaceSessionRepository`, and `WorkspaceRestoration`. The same
`LibraryMutationQueue` serializes workspace and Library changes.

## Events

None today. Autosave exposes a failure stream because a background write has no
awaiting UI call; the composition root forwards it to the controller
(`lib/application/workspace_autosave.dart:31-44`).

## Lifecycle

One WorkspaceSession exists for the process. Startup creates an unbound room.
New and Open replace it. Save binds it on first write; Save As forks it. Bound
desktop and modern-browser sessions autosave, while a download-only web file
stays dirty until the reader explicitly saves.

## Failure and recovery

Malformed documents and unexpected scan failures leave both current projections
untouched. Expected missing sources remain in their original order and appear
as reconnectable shelf rows. Autosave preserves `dirty: true` when a write fails
and reports that failure visibly (`lib/application/workspace_autosave.dart:38-66`).

Save As pauses autosave while it owns the write queue. Cancellation or failure
reschedules the old bound session, preventing a silent permanently-dirty state
(`lib/application/use_cases/save_workspace.dart:77-115`).

## Transition

The lifecycle is part of the reader's durable core rather than an optional
plugin. A new workspace field affects the domain model, format version, codec,
schema, and restoration tests together. Keeping those pieces aligned lets an
older or unavailable source fail honestly instead of being misread.
