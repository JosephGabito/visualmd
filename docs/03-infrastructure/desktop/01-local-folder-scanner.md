# Local Folder Scanner

## Purpose and boundary

Implements both folder scanning ports for folders on the local filesystem
(`lib/infrastructure/io/local_folder_scanner.dart`). It is the desktop
twin of [Browser Folder Scanner](../web/03-folder-scanner.md): it reads bytes,
returns `FileEntry` values (`lib/infrastructure/io/local_folder_scanner.dart`),
and leaves building the `Library` to the domain. It
applies the same two domain rules at the edge — only markdown, no hidden
folders — so it avoids reading what the domain would discard.

Unlike the browser scanner it is fully testable on the VM, and it is:
`test/infrastructure/local_folder_scanner_test.dart` creates a real temp tree
and scans it (`test/infrastructure/local_folder_scanner_test.dart`).

## Present wiring

`scan(ref)` (`lib/infrastructure/io/local_folder_scanner.dart`) looks
the ref up in the `LocalFolderRegistry`, throws `FolderUnavailable` when it
is unknown (`lib/infrastructure/io/local_folder_scanner.dart`), then switches on the handle:

| Handle | Path | Evidence |
|--------|------|----------|
| `LocalDirectory(path, bookmark)` | `_walk(Directory(path))`, wrapped in `_access.within(bookmark, …)` | `lib/infrastructure/io/local_folder_scanner.dart` |
| `LocalFiles(files)` | for each `(path, bookmark)`: keep if `MarkdownFile.isMarkdown(baseName)`, read inside `_access.within` | `lib/infrastructure/io/local_folder_scanner.dart` |

`_walk` lists the directory with `Directory.list(followLinks: false)` —
symlinks are not followed, which rules out cycles and escaping the chosen
folder (`lib/infrastructure/io/local_folder_scanner.dart`). For each entry:

- a `Directory` is skipped if `HiddenFolders.isHidden(name)`, otherwise
  recursed into with the prefix extended by `name/` (`lib/infrastructure/io/local_folder_scanner.dart`);
- a `File` is read only if `MarkdownFile.isMarkdown(name)` (`lib/infrastructure/io/local_folder_scanner.dart`).

`_read` decodes with `utf8.decode(..., allowMalformed: true)`, so a stray
Latin-1 byte in one file produces a replacement character rather than
failing the whole library (`lib/infrastructure/io/local_folder_scanner.dart`).

The `ScopedAccess` it is constructed with defaults to `OpenAccess`
(`lib/infrastructure/io/local_folder_scanner.dart`); the desktop `PlatformAdapters` passes `DesktopSecurityScope` so
macOS drops can be read under the sandbox
(`lib/infrastructure/platform/platform_io.dart`). See
[macOS Sandbox](04-macos-sandbox.md).

## Inputs and outputs

| Direction | What | Evidence |
|-----------|------|----------|
| in | `FolderRef` from the desktop drop or picker | `lib/infrastructure/platform/platform_io.dart` |
| out | `ScannedFolder(name, files)` — name from the handle (`LocalDirectory.name` is the path's base name), paths `/`-joined relative to the folder | `lib/infrastructure/platform/platform_io.dart`, `lib/infrastructure/io/local_folder.dart` |
| out (error) | `FolderUnavailable(ref)` | `lib/infrastructure/io/local_folder.dart` |

Loose files keep only their base name as path, so a `LocalFiles` library is
always flat (`lib/infrastructure/io/local_folder.dart`).

## Events

None. `AddFolder` owns the library change after a successful scan.

## Lifecycle

One instance per desktop `PlatformAdapters`; stateless beyond the registry.
Every full `scan` walks the tree afresh. `scanDocument` validates one portable
relative path and rereads only that Markdown after a watcher invalidation
(`lib/infrastructure/io/local_folder_scanner.dart`). Watching itself is
owned separately by [Desktop Source Change Monitor](07-source-change-monitor.md).

## Failure and recovery

What the tests pin down (`test/infrastructure/local_folder_scanner_test.dart`):

| Behaviour | Test |
|-----------|------|
| only markdown is returned; dot-prefixed and recognised dependency/runtime trees are never entered; deep nesting keeps its relative path | `test/infrastructure/local_folder_scanner_test.dart` |
| invalid UTF-8 does not fail the scan | `test/infrastructure/local_folder_scanner_test.dart` |
| loose files become a flat library with non-Markdown dropped | `test/infrastructure/local_folder_scanner_test.dart` |
| an unknown ref raises `FolderUnavailable` | `test/infrastructure/local_folder_scanner_test.dart` |

Not handled today: a file that disappears between listing and reading, or a
directory the process cannot read, surface as the underlying `FileSystemException`
and fail the scan as a whole; the controller shows “Couldn't open”
(`lib/api/reader_controller.dart`).

## Transition

- Concurrent reads with a bounded pool would speed up large libraries
  without changing the port.
- Relative image bytes are read on demand by `LocalDocumentImageLoader`, a
  separate port adapter. The scanner therefore remains Markdown-only and an
  image symlink cannot escape the canonical offered root
  (`lib/infrastructure/io/local_document_image_loader.dart`).
