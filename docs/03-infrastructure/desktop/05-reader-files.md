# Reader Files

## Purpose and boundary

`ReaderFiles` owns Visual MD's private application-support files: preferences,
user themes, and machine-local workspace source bindings. It moves strings,
paths, and bookmark bytes; it does not interpret themes or Workspace JSON.

## Present wiring

The desktop platform family locates one instance and uses it for preferences,
themes, and `DesktopWorkspaceSourceAccess`
(`lib/infrastructure/platform/platform_io.dart:26-50`,
`lib/infrastructure/platform/platform_io.dart:64-69`). `locate` creates the
application-support root and a self-documenting themes directory
(`lib/infrastructure/io/reader_files.dart:23-37`).

| Path | Holds |
|------|-------|
| `Visual MD/preferences.json` | String preferences. |
| `Visual MD/workspace-access.json` | Machine-local path and optional bookmark by Workspace/source IDs. |
| `Visual MD/themes/*.json` | User theme documents, read in name order. |
| `Visual MD/themes/README.md` | First-run theme format guide. |

Workspace access records are addressed as `workspaceId/sourceId`
(`lib/infrastructure/io/reader_files.dart:79-104`). Save As copies only the
named source bindings to the new Workspace ID
(`lib/infrastructure/io/reader_files.dart:106-117`).

## Inputs and outputs

Preference methods accept a string key and value. Theme reads return
`(origin, json)` records. Workspace access reads return a path plus optional
bookmark bytes; writes and forks retain those values locally.

Every private JSON write uses a `.writing` temporary and the native atomic
replacement adapter, retaining `.bak` as the previous complete file
(`lib/infrastructure/io/reader_files.dart:119-130`).

## Events

None. This adapter answers ports and never publishes domain events.

## Lifecycle

One instance is created before the first frame and lives for the process. It
does not cache JSON; every operation reads current disk state, so recovery and
manual inspection are deterministic.

## Failure and recovery

A missing or malformed preferences or access file reads as empty
(`lib/infrastructure/io/reader_files.dart:45-53`,
`lib/infrastructure/io/reader_files.dart:69-77`). A failed replacement leaves
the target and backup available rather than presenting a partial JSON file.
Non-JSON theme files are ignored; theme-format errors belong to ThemeRegistry.

## Transition

Live theme reload and revealing the themes directory remain separate platform
capabilities. Keeping workspace authority in this private store lets a
workspace document be shared without also sharing bookmark bytes or other
machine-specific permission material.
