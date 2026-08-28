# Workspace Persistence

## Purpose and boundary

Workspace persistence implements the application ports for public workspace
JSON, user-selected files, and machine-local source access. Portable intent and
machine authority stay separate, so sharing a workspace file does not also
share a sandbox bookmark, browser handle, or hidden platform token.

## Present wiring

`WorkspaceJsonCodec` accepts only the version 1 field set, validates the format
marker, and delegates path and identity invariants to the domain
(`lib/infrastructure/workspace/workspace_json_codec.dart`). Encoding is
stable, indented JSON with a trailing newline
(`lib/infrastructure/workspace/workspace_json_codec.dart`). Unknown fields
are rejected rather than silently discarded
(`lib/infrastructure/workspace/workspace_json_codec.dart`).

Desktop workspace files use native open/save panels. The adapter preserves the
exact path returned by the save panel because macOS grants access to that URL,
not to a renamed sibling (`lib/infrastructure/io/desktop_workspace_files.dart`).
Finder-opened workspaces instead receive a security-scoped bookmark while the
system open grant is live. `DesktopWorkspaceFiles` retains that path and
bookmark behind a process-local `WorkspaceFileRef`, opens the scope around
reads and automatic saves, and never exposes the native path inward
(`lib/infrastructure/io/desktop_workspace_files.dart`).
On macOS, Foundation writes that selected URL atomically through the native
channel (`macos/Runner/MainFlutterWindow.swift`). Windows keeps the
temporary-file replacement and last-good backup implemented by its runner.
Machine-local source access is keyed by Workspace ID and source ID, so two
workspaces may grant different authority to the same path.

On macOS that local record contains a security-scoped bookmark. On Windows the
portable absolute root and relative path reconstruct the location, while the
same local registry shape remains available. Browser implementations prefer
File System Access handles stored in IndexedDB; upload/download fallback refs
explicitly disable automatic writes.

## Inputs and outputs

| Port | Desktop adapter | Web adapter |
|------|-----------------|-------------|
| `WorkspaceFiles` | native file panels and atomic replacement | File System Access handle, or upload/download |
| `WorkspaceSourceAccess` | paths and macOS bookmarks in reader-owned JSON | file/directory handles in IndexedDB |
| `WorkspaceCodec` | `WorkspaceJsonCodec` | `WorkspaceJsonCodec` |
| `WorkspaceIds` | opaque random IDs | opaque random IDs |

The suggested filename uses the public `.visualmd-workspace.json` suffix
(`lib/application/ports/workspace_files.dart`). The final name remains
the reader's choice in the platform panel; changing it afterward would discard
the authority represented by that selection.

## Events

None. Adapters implement requested reads and writes; application state decides
when persistence happens.

## Lifecycle

Platform adapters are created once at startup. A selected workspace file is
represented by an opaque `WorkspaceFileRef` for the current run. Durable source
bindings outlive that run in the platform's local store and are copied to a new
Workspace ID during Save As.

## Failure and recovery

The codec reports actionable `WorkspaceFormatException`s. Opening parses and
restores before replacing live state. Atomic writes leave the previous target
intact when replacement fails; the Windows and non-native fallback additionally
retain `.bak` as the last known complete file
(`lib/infrastructure/io/desktop_atomic_files.dart`). Missing or denied
source authority becomes an unavailable source, not a partially restored
Library.

On browsers without writable handles, Save downloads a new file only when the
reader explicitly invokes it. Deferred changes remain visibly dirty rather
than causing repeated downloads.

## Transition

Format version 1 is public and described by
`schemas/visualmd-workspace-v1.schema.json`. A future version will need an
explicit migration path. Rejecting unknown fields today keeps older builds from
silently discarding data they do not understand, while preserving the boundary
between portable addresses and machine-local authority.
