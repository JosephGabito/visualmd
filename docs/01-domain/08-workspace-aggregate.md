# Workspace Aggregate

## Purpose and boundary

A `Workspace` is the durable reading room. It records which sources belong to
the room, their order, the selected theme, and the document the reader was
using. It does not contain Markdown bytes, parsed folders, panel widths, or
platform capabilities. Those are reconstructed or stored elsewhere.

This aggregate lives in the framework-free domain ring. The `Library` remains
the in-memory projection containing actual documents; a Workspace is the
portable intent from which that projection is rebuilt.

## Present wiring

The aggregate stores a stable `WorkspaceId`, an optional absolute document
root, two ordered source collections, one theme value, and an optional active
document address (`lib/domain/workspace/workspace.dart:5-25`). It rejects
duplicate source identities and an active document whose source is not a
member (`lib/domain/workspace/workspace.dart:26-41`).

Every source has an opaque stable identity, a display name, and a path relative
to the document root (`lib/domain/workspace/workspace_source.dart:3-21`). Paths
use `/`, may not be absolute, and may not contain empty, `.` or `..` segments,
so a serialized source cannot escape its declared root
(`lib/domain/workspace/workspace_source.dart:41-58`).

## Inputs and outputs

| Value | Meaning |
|-------|---------|
| `WorkspaceId` | Durable identity used to associate platform access grants. |
| `documentRootAbsolutePath` | Common absolute root on desktop; null where a platform cannot expose one. |
| `markdowns` | Ordered standalone Markdown sources. |
| `folders` | Ordered Library roots. |
| `WorkspaceTheme` | Fixed theme or system-following light/dark pair. |
| `WorkspaceDocument` | Source identity plus relative path of the active document. |

`sources` yields standalone Markdowns followed by folders, matching the shelf's
two visible sections (`lib/domain/workspace/workspace.dart:43-55`). `copyWith`
returns a newly validated aggregate rather than allowing partial mutation
(`lib/domain/workspace/workspace.dart:57-77`).

## Events

None today. Workspace changes are committed through application use cases; the
planned plugin event system is not required for persistence.

## Lifecycle

New Workspace creates a fresh identity and an empty, unbound aggregate. Open
Workspace decodes an existing aggregate and restores its Library projection.
Save As creates a new identity because the result is a fork, while Save keeps
the current identity.

## Failure and recovery

Construction fails when identities conflict, the active source is not a
member, the root is not absolute, or a relative path is unsafe
(`lib/domain/workspace/workspace.dart:30-39`,
`lib/domain/workspace/workspace.dart:98-115`). A malformed JSON document is
therefore rejected before it can replace the current reading room.

An unavailable platform source remains a Workspace member. It is omitted only
from the current Library projection and can be reconnected into its saved slot.

## Transition

Version 1 stores source membership rather than file contents. Additional
durable reading state can arrive through a versioned schema when the product
needs it. Platform access tokens stay in the reader's machine-local storage:
they are neither portable nor appropriate content for a workspace JSON file.
