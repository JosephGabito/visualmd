# macOS

Native desktop build. Same domain, application, and API as the web; the
`io/` adapter family replaces the browser one.

## Prerequisites

One-time, on the build machine:

1. Install Xcode from the App Store (the Command Line Tools alone are not
   enough — `xcodebuild` and the macOS SDK ship only with Xcode).
2. `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer`
3. `sudo xcodebuild -runFirstLaunch` (accepts the licence, installs
   components; harmless if Xcode was already opened once).

CocoaPods is currently required for the pinned native Mermaid renderer. Merman
0.7 ships both CocoaPods and Swift Package Manager support, but Flutter's
generated SPM symlink does not preserve the renderer's sibling XCFramework.
The project therefore selects the package's CocoaPods path in `pubspec.yaml`
and keeps `macos/Podfile` plus its lockfile in source control. Flutter runs the
pod installation as part of the macOS build.

## Build and run

```sh
flutter run -d macos       # develop with hot reload
flutter build macos        # release build
open "build/macos/Build/Products/Release/Visual MD.app"
```

The app name comes from `PRODUCT_NAME = Visual MD`
(`macos/Runner/Configs/AppInfo.xcconfig`); the bundle identifier is
`com.visualmd.visualmd` (`macos/Runner/Configs/AppInfo.xcconfig`).

## Sandbox and entitlements

The app runs sandboxed. Both entitlement files grant user-selected read-write
file access, app-scoped bookmarks, and network client access:
`macos/Runner/Release.entitlements` and, with
the debug-only JIT and server entries, `macos/Runner/DebugProfile.entitlements`.
Dropped folders from Finder and workspace restoration use security-scoped
bookmarks that bracket filesystem access. The workspace binding retains an
app-scoped bookmark locally, outside the shared JSON. Full detail in
[macOS Sandbox](../03-infrastructure/desktop/04-macos-sandbox.md).

The bundle registers as an alternate Markdown and JSON viewer
(`macos/Runner/Info.plist`). LaunchServices classifies by the final extension,
so it cannot register the compound `.visualmd-workspace.json` suffix alone;
the Dart edge accepts only that exact suffix and ignores other JSON. Finder
double-click and Open With are delivered for both cold and warm launches. The
delegate queues early requests until Dart is ready, while the window creates
the security-scoped bookmarks needed after the system callback returns
(`macos/Runner/AppDelegate.swift`, `macos/Runner/MainFlutterWindow.swift`,
`lib/infrastructure/io/desktop_external_open_items.dart`).

Workspace Save As keeps the exact URL returned by `NSSavePanel`. The runner
writes that URL with Foundation's atomic option, allowing macOS to manage the
auxiliary file without exposing an ungranted sibling path to Dart
(`lib/infrastructure/io/desktop_workspace_files.dart`,
`macos/Runner/MainFlutterWindow.swift`).

## Reader files

Preferences and user themes live in the app's application-support directory,
inside a `Visual MD` folder created on first launch
(`lib/infrastructure/io/reader_files.dart`). Because the app is
sandboxed, that is inside its container rather than directly under
`~/Library/Application Support`.

| File | Holds |
|------|-------|
| `Visual MD/preferences.json` | The saved theme choice, as JSON |
| `Visual MD/workspace-access.json` | Local source paths and sandbox bookmarks |
| `Visual MD/themes/*.json` | One user theme per file |
| `Visual MD/themes/README.md` | Written on first run; documents the theme format |

The theme menu offers **Open themes folder**, which hands that private directory
to Finder without exposing its sandbox path in the interface
(`lib/infrastructure/platform/platform_io.dart`). Details in
[Reader Files](../03-infrastructure/desktop/05-reader-files.md) and
[Creating a Theme](../09-contributing/05-creating-a-theme.md).

## Window chrome

`MainFlutterWindow.swift` hides the system title bar, extends content under
it, and attaches an empty unified toolbar so the traffic lights sit centred in
a zone measured at startup (52 px fallback); minimum window size is 720 × 480
(`macos/Runner/MainFlutterWindow.swift`). The toolbar is hidden while
fullscreen because there are no persistent traffic lights to position; this
lets the Flutter top bar reach the top edge instead of leaving an empty native
strip (`macos/Runner/MainFlutterWindow.swift`). The Dart side reads the
title-bar height at startup and answers the UI with a taller, 84 px-inset top
bar that doubles as a drag handle with double-click-to-zoom
(`lib/infrastructure/platform/platform_io.dart`,
`lib/infrastructure/platform/platform_io.dart`). See
[Window Chrome](../03-infrastructure/desktop/03-window-chrome.md).

The initial content frame is 1280 × 800, wide enough to enter the reader's
full desktop composition instead of its compact mode. After the first launch,
AppKit saves moves and resizes under the stable `visualmd.main-window` autosave
name and restores the last frame at startup. The window remains resizable down
to the smaller minimum above (`macos/Runner/Base.lproj/MainMenu.xib`,
`macos/Runner/MainFlutterWindow.swift`).

The application File menu is native AppKit chrome, inserted beside the app
menu after AppKit has installed the menu bar. Its Command-O Open panel accepts
folders and Markdown files in one multi-selection operation; Command-Shift-O
opens a workspace, while Command-Option-O opens the bundled sample library.
New, Save, Save As, Add Folder, and Add Markdown remain explicit actions
(`macos/Runner/MainFlutterWindow.swift`). Edit is reduced to Copy, Select All,
and the two reader search scopes. Help contains only shortcuts, support,
privacy, and open-source licences. Reader-dependent items validate against a
small Flutter state projection, while Shelf and Outline show their current
visibility with native checkmarks (`lib/infrastructure/io/desktop_commands.dart`,
`macos/Runner/MainFlutterWindow.swift`). The Flutter top bar does not duplicate
the menu.

Although the custom title bar hides AppKit's title, the native window title
still follows the open document for Mission Control and accessibility. With no
document it falls back to **Visual MD** (`lib/main.dart`,
`macos/Runner/MainFlutterWindow.swift`).

## Status

Built and launched on 2026-08-24. Verified visually: the native File menu sits
beside View and Window, the Flutter top bar contains no duplicate, and the
single-title-bar chrome keeps the traffic lights centred without carrying an
empty toolbar into fullscreen. Workspace codec, selected-path preservation,
atomic writing, source binding, native menu validation, hidden-title syncing,
fullscreen chrome, last-frame restoration, and lifecycle behavior are covered
by automated tests.

The Mac App Store route now has a team-signed archive that passes the bundle
and archive validators, including matching Merman dSYM UUIDs. Upload processing
and App Review remain outside the repository. A direct download is a separate
route and still needs a Developer ID Application identity, notarization,
stapling, and verification on a clean machine.

## Troubleshooting

- `xcrun: error: unable to find utility "xcodebuild"` — step 2 above was
  skipped; `xcode-select -p` should print the Xcode path.
- A permitted folder cannot be read — inspect the security-scope grant and the
  resulting `FileSystemException`. Keep the sandbox enabled so the diagnosis
  follows the same access path as a release build.
