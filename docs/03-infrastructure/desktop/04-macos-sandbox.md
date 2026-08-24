# macOS Sandbox

## Purpose and boundary

The macOS app runs sandboxed. Knowing a path is not enough to read outside the
container; the reader also needs permission granted by macOS. This document
follows that permission from a picker or drop, through workspace restoration,
to the `ScopedAccess` seam that opens it for the duration of a read. A Finder
folder drop was verified under the sandbox on 2026-08-22.

## Present wiring

**Entitlements.** Both profiles enable the sandbox and the release
capabilities; the debug profile adds Flutter tooling permissions:

| Entitlement | Why | Debug | Release |
|-------------|-----|-------|---------|
| `com.apple.security.app-sandbox` | the app is sandboxed at all | `macos/Runner/DebugProfile.entitlements` | `macos/Runner/Release.entitlements` |
| `com.apple.security.files.user-selected.read-write` | open and save files chosen through native panels, and read dropped sources | `macos/Runner/DebugProfile.entitlements` | `macos/Runner/Release.entitlements` |
| `com.apple.security.files.bookmarks.app-scope` | create durable access bookmarks for workspace sources | `macos/Runner/DebugProfile.entitlements` | `macos/Runner/Release.entitlements` |
| `com.apple.security.network.client` | allow a user theme's unbundled web font fallback | `macos/Runner/DebugProfile.entitlements` | `macos/Runner/Release.entitlements` |
| `com.apple.security.cs.allow-jit` | Flutter debug mode JIT | `macos/Runner/DebugProfile.entitlements` | — |
| `com.apple.security.network.server` | Flutter debug tooling (hot reload, DevTools) | `macos/Runner/DebugProfile.entitlements` | — |

**Where the grant comes from.**

| Source of folder | Grant | Bookmark carried? |
|------------------|-------|-------------------|
| open panel (`DesktopFolderPicker`) | the panel itself grants access to the selection | no — `LocalDirectory(path)` (`lib/infrastructure/io/desktop_folder_picker.dart`) |
| Finder drop (`DesktopFolderDrop`) | a security-scoped bookmark supplied by `desktop_drop` as `extraAppleBookmark` | yes — stored on the handle (`lib/infrastructure/io/desktop_folder_drop.dart`, `lib/infrastructure/io/local_folder.dart`) |

**Turning the grant on and off.** `ScopedAccess.within(bookmark, body)` is
the seam (`lib/infrastructure/io/scoped_access.dart`). Two implementations:

- `OpenAccess` — runs `body` as is; the default for the scanner and the
  right choice on every non-macOS desktop and in tests
  (`lib/infrastructure/io/scoped_access.dart`,
  `lib/infrastructure/io/local_folder_scanner.dart`).
- `DesktopSecurityScope` — if not macOS, or the bookmark is null or empty,
  just runs `body`; otherwise calls
  `DesktopDrop.instance.startAccessingSecurityScopedResource(bookmark:)`,
  runs `body`, and in `finally` calls `stopAccessingSecurityScopedResource`
  only if access was granted (`lib/infrastructure/io/desktop_security_scope.dart`).

The scanner brackets the *whole directory walk* in one `within` for a
`LocalDirectory`, and each file read for `LocalFiles`
(`lib/infrastructure/io/local_folder_scanner.dart`). The desktop
`PlatformAdapters` is the only place `DesktopSecurityScope` is constructed
(`lib/infrastructure/platform/platform_io.dart`).

## Inputs and outputs

| Direction | What | Evidence |
|-----------|------|----------|
| in | `Uint8List? bookmark` on the handle | `lib/infrastructure/io/local_folder.dart` |
| in | the read to perform | `lib/infrastructure/io/scoped_access.dart` |
| out | the read's result, with the scope closed afterwards | `lib/infrastructure/io/desktop_security_scope.dart` |

## Events

None. The adapter grants access for a requested read; application use cases own
the library mutation that follows.

## Lifecycle

A bookmark is held on the `LocalFolder` handle for the session, while the scope
is opened only for the duration of a scan. Workspace sources also receive a
durable app-scoped bookmark in the reader's private access file; reopening a
workspace resolves that bookmark, refreshes it when macOS reports it stale,
and re-registers the resulting path locally
(`lib/infrastructure/io/desktop_workspace_source_access.dart`,
`lib/infrastructure/io/desktop_workspace_source_access.dart`). The public workspace JSON contains paths and source ids, not the
bookmark bytes.

## Failure and recovery

- `startAccessingSecurityScopedResource` returning `false` leaves
  `granted = false`; the read is still attempted and, if the sandbox refuses
  it, fails with a `FileSystemException` that the controller shows as
  “Couldn't open” (`lib/api/reader_controller.dart`). `stop` is then
  skipped because no scope was opened
  (`lib/infrastructure/io/desktop_security_scope.dart`).
- Drops delivered as file promises land inside the app's container with no
  bookmark; `within` sees an empty bookmark and simply reads.
- If a permitted folder cannot be read, inspect the bookmark grant and the
  resulting `FileSystemException` first. The sandbox stays enabled during
  diagnosis so tests exercise the same boundary as the shipped app.

## Transition

The built-in fonts are already bundled. If the optional fallback for unbundled
theme fonts moves fully offline, `network.client` can be removed after verifying
custom themes. Signing and notarization are the next platform-wide checks for
bookmark restoration outside a developer build.
