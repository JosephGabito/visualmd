# 0005 — FolderRef as an Opaque Handle

Status: Accepted · 2026-08-22

## Context

The thing a reader drops on the app is different on every platform: a browser
`FileSystemDirectoryEntry`, a browser `FileList` with relative paths, a path
on disk, a path plus a macOS security-scoped bookmark. The `AddFolder` use
case must be able to say "open that" without knowing any of those types, and
the drop must be captured synchronously in the platform event while the
scanning happens later, asynchronously.

## Decision

The application's name for "a folder the reader offered" is `FolderRef`: an
opaque `id` plus a display `name`, equal by id. Each adapter family keeps a
`FolderRegistry<T>` that maps ids to its own handle type and issues refs.
The family's scanner looks the ref up in the same registry; a ref it does not
recognise raises `FolderUnavailable`, which lets several scanners be composed
behind one port with `RoutingFolderScanner`.

The application and the domain never see a browser object or a filesystem
path. The UI sees a `FolderRef` only as something to pass to a use case.

## Consequences

- Drop handlers can register a handle and emit a ref immediately, satisfying
  the browser's requirement that directory entries be captured inside the
  event handler.
- The bundled sample library is just another scanner with one well-known ref,
  composed in front of the platform scanner.
- Refs are process-scoped: they are not serialisable and do not survive a
  restart. Workspace restoration now stores portable source identity
  separately from local platform authority, then re-issues refs through an
  adapter; see
  [0008 — Workspace as the Durable Unit](0008-workspace-as-durable-unit.md).
- There is a small duplication: both `BrowserFolder` and `LocalFolder` are
  sealed families with a directory variant and a loose-files variant. Keeping
  those types separate makes the underlying platform difference explicit.

## Evidence

- `FolderRef` and `FolderUnavailable`: `lib/application/ports/folder_scanner.dart:5-19`, `lib/application/ports/folder_scanner.dart:35-41`.
- The generic registry: `lib/infrastructure/folder_registry.dart:6-20`.
- Per-family handle types and registries: `lib/infrastructure/web/browser_folder.dart:6-31`, `lib/infrastructure/io/local_folder.dart:6-31`.
- Composition of scanners behind one port: `lib/infrastructure/routing_folder_scanner.dart:5-21`, `lib/main.dart:23-26`.
- The use case turns only the opaque ref id into domain identity:
  `lib/application/use_cases/add_folder.dart:40-49`.
- Test that an unknown ref is reported, not crashed on: `test/application/use_cases_test.dart:47-53`, `test/infrastructure/local_folder_scanner_test.dart:88-94`.
