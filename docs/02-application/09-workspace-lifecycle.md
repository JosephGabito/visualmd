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
(`lib/application/use_cases/create_workspace.dart`). `OpenWorkspace`
selects and decodes a file before entering the shared mutation queue
(`lib/application/use_cases/open_workspace.dart`).

Before creating that empty room, `RecoverWorkspace` asks for the private last
session and feeds it through the same complete restoration path. A recovered
room is deliberately unbound and dirty: it may retain a former public
workspace's identity and source authority, but it can never silently write to
that former file (`lib/application/use_cases/recover_workspace.dart`,
`lib/application/use_cases/open_workspace.dart`).

Restore discovers every reachable folder and scans standalone Markdown into
temporary collections. A metadata-capable folder adapter contributes paths and
physical identities without putting authored-title reads on the atomic restore
path. The result carries deferred title work beside the complete Library. Only
expected unavailable-source failures are retained as missing; an unexpected
scanner failure aborts restoration
(`lib/application/use_cases/open_workspace.dart`,
`lib/application/use_cases/open_workspace.dart`). If a restored folder
contains a standalone source, the standalone membership is absorbed and the
active address follows the same physical document into the folder tree
(`lib/application/use_cases/open_workspace.dart`).

The Library and WorkspaceSession replace together only after restoration and
normalization succeed. The controller can then publish that filename shelf
before reading the active document and enrich authored titles through the same
generation-fenced use case as a newly added folder
(`lib/application/use_cases/open_workspace.dart`,
`lib/api/reader_controller.dart`).
Structural changes write first when a bound file supports automatic writes;
theme and active-document changes are coalesced by autosave
(`lib/application/use_cases/update_workspace.dart`).

## Inputs and outputs

| Use case | Input | Output |
|----------|-------|--------|
| `CreateWorkspace` | current theme | unbound dirty `WorkspaceSession` |
| `OpenWorkspace` | selected workspace file | restored session, Library, active Document, and deferred folder titles |
| `RecoverWorkspace` | private last-session journal | the same restored projection, unbound and dirty |
| `SaveWorkspace` | current session | same identity bound and clean |
| `SaveWorkspaceAs` | current session and new file | new identity bound and clean |
| `ReconnectWorkspaceSource` | missing source identity | platform ref plus saved insertion index |
| `UpdateWorkspace` | successful Library mutation or reading choice | synchronized session |

The ports are `WorkspaceFiles`, `WorkspaceCodec`, `WorkspaceSourceAccess`,
`WorkspaceRecoveryStore`, `WorkspaceSessionRepository`, and
`WorkspaceRestoration`. The same
`LibraryMutationQueue` serializes workspace and Library changes.

## Events

None today. Autosave exposes a failure stream because a background write has no
awaiting UI call; the composition root forwards it to the controller
(`lib/application/workspace_autosave.dart`).

## Lifecycle

One WorkspaceSession exists for the process. Desktop startup restores its
private journal when possible and otherwise creates an unbound room. Web
startup creates an empty room because its recovery adapter is intentionally a
no-op. New and Open replace the session. Save binds it on first write; Save As
forks it. Bound desktop and modern-browser sessions autosave, while a
download-only web file stays dirty until the reader explicitly saves
(`lib/main.dart`,
`lib/infrastructure/memory/noop_workspace_recovery_store.dart`).

## Failure and recovery

Malformed documents and unexpected metadata-scan failures leave both current
projections untouched. Deferred title failure does not roll back a usable
filename shelf. Expected missing sources remain in their original order and appear
as reconnectable shelf rows. Autosave preserves `dirty: true` when a write fails
and reports that failure visibly (`lib/application/workspace_autosave.dart`).

Save As pauses autosave while it owns the write queue. Cancellation or failure
reschedules the old bound session, preventing a silent permanently-dirty state
(`lib/application/use_cases/save_workspace.dart`).

Every committed session update also attempts the private journal after the
in-memory commit. Journal failure therefore cannot roll back a live reading
room. A damaged or unreadable journal falls back to an empty startup rather
than blocking launch (`lib/infrastructure/recovery/recovering_workspace_state.dart`,
`lib/application/use_cases/recover_workspace.dart`).

## Transition

The lifecycle is part of the reader's durable core rather than an optional
plugin. A new workspace field affects the domain model, format version, codec,
schema, and restoration tests together. Keeping those pieces aligned lets an
older or unavailable source fail honestly instead of being misread.
