# Workspace Persistence

## Purpose and boundary

Workspace persistence implements the application ports for public workspace
JSON, user-selected files, and machine-local source access. Portable intent and
machine authority stay separate, so sharing a workspace file does not also
share a sandbox bookmark, browser handle, or hidden platform token.

## Present wiring

`WorkspaceJsonCodec` accepts only the version 1 field set, validates the format
marker, and delegates path and identity invariants to the domain
(`lib/infrastructure/workspace/workspace_json_codec.dart:13-60`). Encoding is
stable, indented JSON with a trailing newline
(`lib/infrastructure/workspace/workspace_json_codec.dart:63-84`). Unknown fields
are rejected rather than silently discarded
(`lib/infrastructure/workspace/workspace_json_codec.dart:168-178`).

Desktop workspace files use native open/save panels. Writes go to a temporary
file and replace the target while keeping a last-good backup through the native
atomic-file channel. Machine-local source access is keyed by Workspace ID and
source ID, so two workspaces may grant different authority to the same path.

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

The public filename suffix is `.visualmd-workspace.json`; the application port
normalizes a suggested name exactly once
(`lib/application/ports/workspace_files.dart:22-40`).

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
restores before replacing live state. Desktop replacement retains `.bak` as the
last known complete file, and temporary `.writing` files are never treated as
workspaces. Missing or denied source authority becomes an unavailable source,
not a partially restored Library.

On browsers without writable handles, Save downloads a new file only when the
reader explicitly invokes it. Deferred changes remain visibly dirty rather
than causing repeated downloads.

## Transition

Format version 1 is public and described by
`schemas/visualmd-workspace-v1.schema.json`. A future version will need an
explicit migration path. Rejecting unknown fields today keeps older builds from
silently discarding data they do not understand, while preserving the boundary
between portable addresses and machine-local authority.
