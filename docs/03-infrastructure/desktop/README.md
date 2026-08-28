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
| [Local Folder Scanner](01-local-folder-scanner.md) | Walking a directory and reading its Markdown files | `lib/infrastructure/io/local_folder_scanner.dart` |
| [Desktop Drop, Picker and Links](02-drop-and-picker.md) | Folder drops, the native picker, and external links | `lib/infrastructure/io/desktop_folder_drop.dart`, `lib/infrastructure/io/desktop_folder_picker.dart`, `lib/infrastructure/io/desktop_links.dart` |
| [Window Chrome](03-window-chrome.md) | The native macOS title bar and Visual MD's top-bar geometry | `macos/Runner/MainFlutterWindow.swift`, `lib/infrastructure/platform/platform_io.dart` |
| [macOS Sandbox](04-macos-sandbox.md) | Entitlements and security-scoped file access | `macos/Runner/Release.entitlements`, `lib/infrastructure/io/desktop_security_scope.dart` |
| [Reader Files](05-reader-files.md) | Preferences, user themes, workspace files, and machine-local access records | `lib/infrastructure/io/reader_files.dart` |
| [Local Markdown Scanner](06-local-markdown-scanner.md) | Opening a directly dropped Markdown file and preserving its source identity | `lib/infrastructure/io/local_markdown_scanner.dart` |
| [Desktop Source Change Monitor](07-source-change-monitor.md) | Native directory events, sandbox lifetime, and the five-second failure fallback | `lib/infrastructure/io/desktop_source_change_monitor.dart` |

Two small types make the rest possible. `LocalFolder` carries either one
directory or a set of local files, with an optional macOS security bookmark;
`LocalFolderRegistry` keeps that native information behind a `FolderRef`
(`lib/infrastructure/io/local_folder.dart`). `ScopedAccess` then gives file
reading one interface whether the operating system needs a permission scope or
not (`lib/infrastructure/io/scoped_access.dart`,
`lib/infrastructure/io/desktop_security_scope.dart`).

The implementation uses `desktop_drop` for drop targets and security-scoped
access, `file_selector` for native file panels, and `window_manager` for window
geometry and dragging. Those plugins support Swift Package Manager, but the
pinned Merman renderer temporarily selects CocoaPods for the whole macOS
target because Flutter's generated SPM symlink loses Merman's sibling
XCFramework (`pubspec.yaml`, `macos/Podfile`).

Shelf context commands resolve those same registered handles only at the
desktop edge. `DesktopShelfSourceActions` produces a native absolute path,
opens Finder or the platform file manager around the source, and uses the
source bookmark while doing so. The shelf receives the capability rather than
the path (`lib/infrastructure/io/desktop_shelf_source_actions.dart`,
`lib/infrastructure/io/desktop_links.dart`).

## From Finder to the shelf

1. A reader drops a folder onto Visual MD, chooses one in the native panel, or
   asks Finder to open a Markdown/workspace document.
2. The adapter registers a `LocalDirectory`. A Finder drop may include a
   security bookmark; an open panel already grants access
   (`lib/infrastructure/io/desktop_folder_drop.dart`,
   `lib/infrastructure/io/desktop_folder_picker.dart`).
3. `AddFolder` receives only the resulting `FolderRef` and asks the
   `FolderScanner` port to read it.
4. `LocalFolderScanner` opens any required security scope, walks the directory
   without following symlinks, reads Markdown outside hidden folders, and then
   closes the scope (`lib/infrastructure/io/local_folder_scanner.dart`).
5. `LibraryBuilder` adds the documents and opens the root README when one is
   available.

Workspace open and save use the same native approach: file panels choose the
location, writes replace the destination atomically, and the macOS menu sends
typed commands over a method channel. Security bookmarks allow a saved
workspace to request access to its sources again. The complete contract is in
[Workspace Persistence](../03-workspace-persistence.md).

Finder double-click and Open With enter through a readiness-gated native
channel so cold-launch requests cannot outrun Flutter startup. The desktop
adapter retains each bookmark behind an opaque ref, then uses the ordinary
reader-source or workspace-open path (`lib/infrastructure/io/desktop_external_open_items.dart`,
`macos/Runner/AppDelegate.swift`).
