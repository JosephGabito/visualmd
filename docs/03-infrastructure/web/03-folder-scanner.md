# Browser Folder Scanner

## Purpose and boundary

Implements both folder scanning ports for folders provided by the browser
(`lib/infrastructure/web/browser_folder_scanner.dart`). A full scan indexes one
title at a time into metadata-only `FileEntry` values; `scanDocument` reads one source through its
retained browser capability. `LibraryBuilder` remains responsible for the
library itself. Applying the Markdown and hidden-folder filters while walking
avoids indexing content the domain would discard
(`lib/domain/library/library_builder.dart`).

## Present wiring

`scan(ref)` (`lib/infrastructure/web/browser_folder_scanner.dart`)
looks the ref up in the `BrowserFolderRegistry`, throws `FolderUnavailable`
if it is unknown (`lib/infrastructure/web/browser_folder_scanner.dart`), then switches on the handle's shape:

| Handle | Path | Evidence |
|--------|------|----------|
| `HandleDirectory` | async iteration over a File System Access directory handle | `lib/infrastructure/web/browser_folder_scanner.dart` |
| `DroppedDirectory` | recursive `_walk` over the legacy entry API | `lib/infrastructure/web/browser_folder_scanner.dart` |
| `PickedFiles` | filter each listed path with `_wanted`, index each title, then emit metadata for retained files | `lib/infrastructure/web/browser_folder_scanner.dart` |

The modern handle walk receives child handles directly. It skips hidden
directories, indexes each Markdown title, and assigns stable session identity
through `BrowserSourceIdentity` (`lib/infrastructure/web/browser_folder_scanner.dart`). That identity lets a directly
offered file be recognized when the same physical handle also appears inside a
folder.

The legacy `_walk` lists a directory with `_entriesOf`, then for each entry:

- directories: skip if `HiddenFolders.isHidden(name)`, otherwise recurse with
  the path prefix extended (`lib/infrastructure/web/browser_folder_scanner.dart`);
- files: retain an entry only if `MarkdownFile.isMarkdown(name)`; decode it
  transiently for its title and release the source
  (`lib/infrastructure/web/browser_folder_scanner.dart`).

`_entriesOf` wraps the callback-style `createReader().readEntries()` in a
loop: the browser returns entries in batches (Chrome: 100 at a time) and an
empty batch means the directory is exhausted
(`lib/infrastructure/web/browser_folder_scanner.dart`). `_fileOf`
wraps `FileSystemFileEntry.file()` the same way (`lib/infrastructure/web/browser_folder_scanner.dart`). `_text` is
`File.text()` bridged to a Dart `String` (`lib/infrastructure/web/browser_folder_scanner.dart`).

The domain rules it borrows: `MarkdownFile.isMarkdown`
(`lib/domain/library/markdown_file.dart`) and `HiddenFolders.isHidden` /
`hidesPath` (`lib/domain/library/hidden_folders.dart`). `LibraryBuilder`
applies the same two rules again (`lib/domain/library/library_builder.dart`),
so the scanner's filter is an optimisation, not the source of truth. See
[Shelving Rules](../../01-domain/02-shelving-rules.md).

## Inputs and outputs

| Direction | What | Evidence |
|-----------|------|----------|
| in | `FolderRef` issued by the drop or picker | `lib/domain/library/library_builder.dart` |
| out | `ScannedFolder(name, files)` — name from the handle, paths `/`-separated relative to the folder | `lib/domain/library/library_builder.dart` |
| out (error) | `FolderUnavailable(ref)` | `lib/domain/library/library_builder.dart` |

`FileEntry` is the domain's own input type (`lib/domain/library/library_builder.dart`).

## Events

None. `AddFolder` owns the library mutation after a successful scan.

## Lifecycle

Stateless apart from the registry it reads from; one instance per web
`PlatformAdapters` (`lib/infrastructure/platform/platform_web.dart`). Each
full `scan` walks the folder afresh, indexing titles sequentially without
retaining source. `scanDocument`
reads one path through a modern directory handle, legacy dropped directory, or
picked-file snapshot (`lib/infrastructure/web/browser_folder_scanner.dart`).
See [Browser Source Change Monitor](05-source-change-monitor.md).

## Failure and recovery

- Unknown ref → `FolderUnavailable`, which `RoutingFolderScanner` treats as
  "try the next scanner" (`lib/infrastructure/routing_folder_scanner.dart`)
  and the controller ultimately shows as "Couldn't open"
  (`lib/api/reader_controller.dart`).
- A `DOMException` from a legacy `readEntries` or `file()` callback completes
  the future with the exception message (`lib/api/reader_controller.dart`); the whole scan fails rather than
  returning a partial library.
- Directory entries are walked sequentially; source reads happen only for the
  document being opened or streamed through search.

## Transition

- Source residency is bounded by `ReadDocument`; this adapter owns access, not
  caching.
- `BrowserDocumentImageLoader` now reads a requested relative image through
  the retained directory handle, legacy dropped entry, or selected file list.
  This remains a separate capability, so scanning still reads Markdown only
  (`lib/infrastructure/web/browser_document_image_loader.dart`).
