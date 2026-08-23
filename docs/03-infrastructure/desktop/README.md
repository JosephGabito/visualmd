# Desktop Adapters

The desktop adapters connect Visual MD to local files, native dialogs, and the
application window. They live under `lib/infrastructure/io/` and are selected
by [Platform Adapters](../01-platform-adapters.md) when the Dart runtime offers
`dart:io` rather than the browser interop libraries.

macOS is the verified desktop target today. Windows uses this same Dart adapter
family, but its build still needs verification on a Windows machine.

## On this shelf

| Document | What it introduces | Source |
|----------|--------------------|--------|
| [Local Folder Scanner](01-local-folder-scanner.md) | Walking a directory and reading its Markdown files | `lib/infrastructure/io/local_folder_scanner.dart:14` |
| [Desktop Drop, Picker and Links](02-drop-and-picker.md) | Folder drops, the native picker, and external links | `lib/infrastructure/io/desktop_folder_drop.dart:14`, `lib/infrastructure/io/desktop_folder_picker.dart:8`, `lib/infrastructure/io/desktop_links.dart:4` |
| [Window Chrome](03-window-chrome.md) | The native macOS title bar and Visual MD's top-bar geometry | `macos/Runner/MainFlutterWindow.swift:31-41`, `lib/infrastructure/platform/platform_io.dart:26-35` |
| [macOS Sandbox](04-macos-sandbox.md) | Entitlements and security-scoped file access | `macos/Runner/Release.entitlements:5-10`, `lib/infrastructure/io/desktop_security_scope.dart:9` |
| [Reader Files](05-reader-files.md) | Preferences, user themes, workspace files, and machine-local access records | `lib/infrastructure/io/reader_files.dart:11-149` |
| [Local Markdown Scanner](06-local-markdown-scanner.md) | Opening a directly dropped Markdown file and preserving its source identity | `lib/infrastructure/io/local_markdown_scanner.dart:10-38` |

Two small types make the rest possible. `LocalFolder` carries either one
directory or a set of local files, with an optional macOS security bookmark;
`LocalFolderRegistry` keeps that native information behind a `FolderRef`
(`lib/infrastructure/io/local_folder.dart:6-31`). `ScopedAccess` then gives file
reading one interface whether the operating system needs a permission scope or
not (`lib/infrastructure/io/scoped_access.dart:5-14`,
`lib/infrastructure/io/desktop_security_scope.dart:9-23`).

The implementation uses `desktop_drop` for drop targets and security-scoped
access, `file_selector` for native file panels, and `window_manager` for window
geometry and dragging. On macOS these packages resolve through Swift Package
Manager, so CocoaPods is not part of the build.

## From Finder to the shelf

1. A reader drops a folder onto Visual MD or chooses one in the native panel.
2. The adapter registers a `LocalDirectory`. A Finder drop may include a
   security bookmark; an open panel already grants access
   (`lib/infrastructure/io/desktop_folder_drop.dart:40-42`,
   `lib/infrastructure/io/desktop_folder_picker.dart:16-17`).
3. `AddFolder` receives only the resulting `FolderRef` and asks the
   `FolderScanner` port to read it.
4. `LocalFolderScanner` opens any required security scope, walks the directory
   without following symlinks, reads Markdown outside hidden folders, and then
   closes the scope (`lib/infrastructure/io/local_folder_scanner.dart:28-29`).
5. `LibraryBuilder` adds the documents and opens the root README when one is
   available.

Workspace open and save use the same native approach: file panels choose the
location, writes replace the destination atomically, and the macOS menu sends
typed commands over a method channel. Security bookmarks allow a saved
workspace to request access to its sources again. The complete contract is in
[Workspace Persistence](../03-workspace-persistence.md).
