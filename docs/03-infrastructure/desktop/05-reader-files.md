# Reader Files

## Purpose and boundary

`ReaderFiles` owns Visual MD's private application-support files: preferences,
user themes, machine-local workspace source bindings, and the location of the
last-session journal. It moves strings, paths, and bookmark bytes; the recovery
adapter, not `ReaderFiles`, interprets Workspace JSON.

## Present wiring

The desktop platform family locates one instance and uses it for preferences,
themes, and `DesktopWorkspaceSourceAccess`
(`lib/infrastructure/platform/platform_io.dart`,
`lib/infrastructure/platform/platform_io.dart`). `locate` creates the
application-support root and a self-documenting themes directory
(`lib/infrastructure/io/reader_files.dart`).

| Path | Holds |
|------|-------|
| `Visual MD/preferences.json` | String preferences. |
| `Visual MD/session.json` | Private last reading room; never a public file binding. |
| `Visual MD/workspace-access.json` | Machine-local path and optional bookmark by Workspace/source IDs. |
| `Visual MD/themes/*.json` | User theme documents, read in name order. |
| `Visual MD/themes/README.md` | First-run theme format guide. |

Workspace access records are addressed as `workspaceId/sourceId`
(`lib/infrastructure/io/reader_files.dart`). Save As copies only the
named source bindings to the new Workspace ID
(`lib/infrastructure/io/reader_files.dart`).

## Inputs and outputs

Preference methods accept a string key and value. `sessionJournal` identifies
the recovery adapter's private file without reading it. Theme reads return
`(origin, json)` records. Workspace access reads return a path plus optional
bookmark bytes; writes and forks retain those values locally.

Every private JSON write uses a `.writing` temporary and the native atomic
replacement adapter, retaining `.bak` as the previous complete file
(`lib/infrastructure/io/reader_files.dart`).

## Events

None. This adapter answers ports and never publishes domain events.

## Lifecycle

One instance is created before the first frame and lives for the process. It
does not cache JSON; every operation reads current disk state, so recovery and
manual inspection are deterministic.

## Failure and recovery

A missing or malformed preferences or access file reads as empty
(`lib/infrastructure/io/reader_files.dart`,
`lib/infrastructure/io/reader_files.dart`). A failed replacement leaves
the target and backup available rather than presenting a partial JSON file.
Non-JSON theme files are ignored; theme-format errors belong to ThemeRegistry.
Session parsing and backup fallback belong to
`DesktopWorkspaceRecoveryStore`
(`lib/infrastructure/io/desktop_workspace_recovery_store.dart`).

## Transition

Live theme reload and revealing the themes directory remain separate platform
capabilities. Keeping workspace authority in this private store lets a
workspace document be shared without also sharing bookmark bytes or other
machine-specific permission material.
