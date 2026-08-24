# Local Folder Scanner

## Purpose and boundary

Implements both folder scanning ports for folders on the local filesystem
(`lib/infrastructure/io/local_folder_scanner.dart:14-15`). It is the desktop
twin of [Browser Folder Scanner](../web/03-folder-scanner.md): it reads bytes,
returns `FileEntry` values (`lib/infrastructure/io/local_folder_scanner.dart:21-38`),
and leaves building the `Library` to the domain. It
applies the same two domain rules at the edge — only markdown, no hidden
folders — so it avoids reading what the domain would discard.

Unlike the browser scanner it is fully testable on the VM, and it is:
`test/infrastructure/local_folder_scanner_test.dart` creates a real temp tree
and scans it (`test/infrastructure/local_folder_scanner_test.dart:11-30`).

## Present wiring

`scan(ref)` (`lib/infrastructure/io/local_folder_scanner.dart:21-38`) looks
the ref up in the `LocalFolderRegistry`, throws `FolderUnavailable` when it
is unknown (`:23-24`), then switches on the handle:

| Handle | Path | Evidence |
|--------|------|----------|
| `LocalDirectory(path, bookmark)` | `_walk(Directory(path))`, wrapped in `_access.within(bookmark, …)` | `:28-29` |
| `LocalFiles(files)` | for each `(path, bookmark)`: keep if `MarkdownFile.isMarkdown(baseName)`, read inside `_access.within` | `:30-35` |

`_walk` lists the directory with `Directory.list(followLinks: false)` —
symlinks are not followed, which rules out cycles and escaping the chosen
folder (`:41`). For each entry:

- a `Directory` is skipped if `HiddenFolders.isHidden(name)`, otherwise
  recursed into with the prefix extended by `name/` (`:45-47`);
- a `File` is read only if `MarkdownFile.isMarkdown(name)` (`:48-49`).

`_read` decodes with `utf8.decode(..., allowMalformed: true)`, so a stray
Latin-1 byte in one file produces a replacement character rather than
failing the whole library (`:54-56`).

The `ScopedAccess` it is constructed with defaults to `OpenAccess`
(`:18-19`); the desktop `PlatformAdapters` passes `DesktopSecurityScope` so
macOS drops can be read under the sandbox
(`lib/infrastructure/platform/platform_io.dart:52-56`). See
[macOS Sandbox](04-macos-sandbox.md).

## Inputs and outputs

| Direction | What | Evidence |
|-----------|------|----------|
| in | `FolderRef` from the desktop drop or picker | `:22-23` |
| out | `ScannedFolder(name, files)` — name from the handle (`LocalDirectory.name` is the path's base name), paths `/`-joined relative to the folder | `:37`, `lib/infrastructure/io/local_folder.dart:19` |
| out (error) | `FolderUnavailable(ref)` | `:24` |

Loose files keep only their base name as path, so a `LocalFiles` library is
always flat (`:32-34`).

## Events

None. `AddFolder` owns the library change after a successful scan.

## Lifecycle

One instance per desktop `PlatformAdapters`; stateless beyond the registry.
Every full `scan` walks the tree afresh. `scanDocument` validates one portable
relative path and rereads only that Markdown after a watcher invalidation
(`lib/infrastructure/io/local_folder_scanner.dart:52-117`). Watching itself is
owned separately by [Desktop Source Change Monitor](07-source-change-monitor.md).

## Failure and recovery

What the tests pin down (`test/infrastructure/local_folder_scanner_test.dart`):

| Behaviour | Test |
|-----------|------|
| only markdown is returned; dot-prefixed and recognised dependency/runtime trees are never entered; deep nesting keeps its relative path | `:35-59` |
| invalid UTF-8 does not fail the scan | `:63-72` |
| loose files become a flat library with non-Markdown dropped | `:74-88` |
| an unknown ref raises `FolderUnavailable` | `:115-121` |

Not handled today: a file that disappears between listing and reading, or a
directory the process cannot read, surface as the underlying `FileSystemException`
and fail the scan as a whole; the controller shows “Couldn't open”
(`lib/api/reader_controller.dart:158-187`).

## Transition

- Concurrent reads with a bounded pool would speed up large libraries
  without changing the port.
- Reading images on request (for relative `![]()` links) is a second port,
  not a loosening of the Markdown filter — see
  [Backlog](../../07-roadmap/02-backlog.md).
