# Browser Folder Scanner

## Purpose and boundary

Implements the `FolderScanner` port for folders provided by the browser
(`lib/infrastructure/web/browser_folder_scanner.dart:17-41`). It reads source
bytes and returns `FileEntry` values; `LibraryBuilder` remains responsible for
the library itself. Applying the Markdown and hidden-folder filters before a
read avoids asking the browser for content the domain would discard
(`lib/domain/library/library_builder.dart:13-18`).

## Present wiring

`scan(ref)` (`lib/infrastructure/web/browser_folder_scanner.dart:23-41`)
looks the ref up in the `BrowserFolderRegistry`, throws `FolderUnavailable`
if it is unknown (`:22-23`), then switches on the handle's shape:

| Handle | Path | Evidence |
|--------|------|----------|
| `HandleDirectory` | async iteration over a File System Access directory handle | `:30-31,43-78` |
| `DroppedDirectory` | recursive `_walk` over the legacy entry API | `:32-33,83-98` |
| `PickedFiles` | filter each listed path with `_wanted`, then read the retained files | `:34-38,80-81` |

The modern handle walk receives child handles directly. It skips hidden
directories, reads Markdown file handles, and assigns stable session identity
through `BrowserSourceIdentity` (`:43-78`). That identity lets a directly
offered file be recognized when the same physical handle also appears inside a
folder.

The legacy `_walk` lists a directory with `_entriesOf`, then for each entry:

- directories: skip if `HiddenFolders.isHidden(name)`, otherwise recurse with
  the path prefix extended (`:88-92`);
- files: read only if `MarkdownFile.isMarkdown(name)`, via `_fileOf` then
  `_text` (`:93-95`).

`_entriesOf` wraps the callback-style `createReader().readEntries()` in a
loop: the browser returns entries in batches (Chrome: 100 at a time) and an
empty batch means the directory is exhausted
(`lib/infrastructure/web/browser_folder_scanner.dart:100-120`). `_fileOf`
wraps `FileSystemFileEntry.file()` the same way (`:122-129`). `_text` is
`File.text()` bridged to a Dart `String` (`:131-132`).

The domain rules it borrows: `MarkdownFile.isMarkdown`
(`lib/domain/library/markdown_file.dart:5-9`) and `HiddenFolders.isHidden` /
`hidesPath` (`lib/domain/library/hidden_folders.dart:24-33`). `LibraryBuilder`
applies the same two rules again (`lib/domain/library/library_builder.dart:30-31`),
so the scanner's filter is an optimisation, not the source of truth. See
[Shelving Rules](../../01-domain/02-shelving-rules.md).

## Inputs and outputs

| Direction | What | Evidence |
|-----------|------|----------|
| in | `FolderRef` issued by the drop or picker | `:24-25` |
| out | `ScannedFolder(name, files)` — name from the handle, paths `/`-separated relative to the folder | `:40` |
| out (error) | `FolderUnavailable(ref)` | `:26` |

`FileEntry` is the domain's own input type (`lib/domain/library/library_builder.dart:11-16`).

## Events

None. `AddFolder` owns the library mutation after a successful scan.

## Lifecycle

Stateless apart from the registry it reads from; one instance per web
`PlatformAdapters` (`lib/infrastructure/platform/platform_web.dart:26-43`). Each
`scan` walks the folder afresh — there is no cache, so re-opening the same ref
re-reads the files.

## Failure and recovery

- Unknown ref → `FolderUnavailable`, which `RoutingFolderScanner` treats as
  "try the next scanner" (`lib/infrastructure/routing_folder_scanner.dart:13-17`)
  and the controller ultimately shows as "Couldn't open"
  (`lib/api/reader_controller.dart:158-187`).
- A `DOMException` from a legacy `readEntries` or `file()` callback completes
  the future with the exception message (`:112-114,126`); the whole scan fails rather than
  returning a partial library.
- Files are read sequentially; a very large library is slow but bounded.

## Transition

- A bounded pool of concurrent reads could improve large-library performance
  without changing the port.
- Images referenced by documents are not read today. Supporting them means
  reading non-Markdown files by request through a separate capability. It is
  tracked in [Backlog](../../07-roadmap/02-backlog.md).
