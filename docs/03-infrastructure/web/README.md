# Web Adapters

The web adapters let Visual MD read local Markdown inside a browser. They use
`package:web` and `dart:js_interop` directly, with no Flutter plugins, and are
selected by [Platform Adapters](../01-platform-adapters.md) when browser interop
is available.

Files stay local to the page. Visual MD does not upload their contents to an
application service.

## On this shelf

| Document | What it introduces | Source |
|----------|--------------------|--------|
| [Browser Folder Drop](01-folder-drop.md) | Document-level folder drag-and-drop | `lib/infrastructure/web/browser_folder_drop.dart:15` |
| [Browser Folder Picker](02-folder-picker.md) | Choosing a folder through the browser | `lib/infrastructure/web/browser_folder_picker.dart:12` |
| [Browser Folder Scanner](03-folder-scanner.md) | Reading Markdown from dropped or selected folder handles | `lib/infrastructure/web/browser_folder_scanner.dart:17` |
| [Browser Markdown Drop](04-markdown-drop.md) | Recognizing one directly dropped Markdown file and keeping its physical identity where possible | `lib/infrastructure/web/browser_markdown_scanner.dart:9` |

`BrowserFolder` represents either a directory walked lazily or a set of files
selected up front. `BrowserFolderRegistry` keeps those browser objects behind a
small `FolderRef` (`lib/infrastructure/web/browser_folder.dart:6-41`); the
general pattern is described in [Folder Registry](../02-folder-registry.md).
External links use `openInBrowser`, which opens a new tab with
`noopener,noreferrer` (`lib/infrastructure/web/browser_links.dart:4-6`).

## From a browser drop to the shelf

1. A reader drops a folder on the page or chooses one with *Open a folder*.
2. The adapter captures the directory entry during the drop event, or the
   selected `FileList` during the input event. It registers that handle and
   returns a `FolderRef` (`lib/infrastructure/web/browser_folder_drop.dart:57-76`,
   `lib/infrastructure/web/browser_folder_picker.dart:17-25`, `:50-64`).
3. `ReaderController.openFolder` passes the reference to `AddFolder`, which
   asks the `FolderScanner` port for entries.
4. `RoutingFolderScanner` gives `BrowserFolderScanner` the reference. The
   scanner walks or filters the registered handle and returns `FileEntry`
   values (`lib/infrastructure/web/browser_folder_scanner.dart:23-41`).
5. `LibraryBuilder` shelves the documents and opens the root README when one is
   available.

Browser entries, files, and DOM events remain in infrastructure throughout
that journey. The application receives references and source strings, so its
behavior stays shared with desktop.

## Workspace files and browser support

When the File System Access API is available, Visual MD can retain directory
and file handles in IndexedDB under the workspace and source IDs. Browsers
without that API use standard file controls instead: opening reads the chosen
JSON into the page process, saving downloads a new JSON file, and source access
may need to be granted again. Both paths are described in
[Workspace Persistence](../03-workspace-persistence.md).
