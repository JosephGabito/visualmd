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

CocoaPods is **not** required: every plugin in use (`desktop_drop`,
`file_selector`, `window_manager`, `pubspec.yaml:15-17`) ships Swift
Package Manager support, and the project has no `Podfile`.

## Build and run

```sh
flutter run -d macos       # develop with hot reload
flutter build macos        # release build
open "build/macos/Build/Products/Release/Visual MD.app"
```

The app name comes from `PRODUCT_NAME = Visual MD`
(`macos/Runner/Configs/AppInfo.xcconfig:8`); the bundle identifier is
`com.visualmd.visualmd` (`macos/Runner/Configs/AppInfo.xcconfig:11`).

## Sandbox and entitlements

The app runs sandboxed. Both entitlement files grant user-selected read-write
file access, app-scoped bookmarks, and network client access:
`macos/Runner/Release.entitlements:5-12` and, with
the debug-only JIT and server entries, `macos/Runner/DebugProfile.entitlements:5-14`.
Dropped folders from Finder and workspace restoration use security-scoped
bookmarks that bracket filesystem access. The workspace binding retains an
app-scoped bookmark locally, outside the shared JSON. Full detail in
[macOS Sandbox](../03-infrastructure/desktop/04-macos-sandbox.md).

Workspace Save As keeps the exact URL returned by `NSSavePanel`. The runner
writes that URL with Foundation's atomic option, allowing macOS to manage the
auxiliary file without exposing an ungranted sibling path to Dart
(`lib/infrastructure/io/desktop_workspace_files.dart:45-65`,
`macos/Runner/MainFlutterWindow.swift:104-127`).

## Reader files

Preferences and user themes live in the app's application-support directory,
inside a `Visual MD` folder created on first launch
(`lib/infrastructure/io/reader_files.dart:14-27`). Because the app is
sandboxed, that is inside its container rather than directly under
`~/Library/Application Support`.

| File | Holds |
|------|-------|
| `Visual MD/preferences.json` | The saved theme choice, as JSON |
| `Visual MD/workspace-access.json` | Local source paths and sandbox bookmarks |
| `Visual MD/themes/*.json` | One user theme per file |
| `Visual MD/themes/README.md` | Written on first run; documents the theme format |

The theme menu prints the exact themes path, which is the reliable way to find
it (`lib/api/widgets/theme_picker.dart:51-54`). Details in
[Reader Files](../03-infrastructure/desktop/05-reader-files.md) and
[Creating a Theme](../09-contributing/05-creating-a-theme.md).

## Window chrome

`MainFlutterWindow.swift` hides the system title bar, extends content under
it, and attaches an empty unified toolbar so the traffic lights sit centred in
a zone measured at startup (52 px fallback); minimum window size is 720 × 480
(`macos/Runner/MainFlutterWindow.swift:31-41`). The Dart side reads the
title-bar height at startup and answers the UI with a taller, 84 px-inset top
bar that doubles as a drag handle with double-click-to-zoom
(`lib/infrastructure/platform/platform_io.dart:26-35`,
`lib/infrastructure/platform/platform_io.dart:106-117`). See
[Window Chrome](../03-infrastructure/desktop/03-window-chrome.md).

The initial content frame is 1280 × 800, wide enough to enter the reader's
full desktop composition instead of its compact mode. The window remains
resizable down to the smaller minimum above
(`macos/Runner/Base.lproj/MainMenu.xib:333-340`).

The application File menu is native AppKit chrome, inserted beside the app
menu after AppKit has installed the menu bar. Its Command-O Open panel accepts
folders and Markdown files in one multi-selection operation; Command-Shift-O
opens a workspace instead. New, Save, Save As, Add Folder, and Add Markdown
remain explicit actions (`macos/Runner/MainFlutterWindow.swift:231-266`). The
Flutter top bar does not duplicate the menu.

## Status

Built and launched on 2026-08-24. Verified visually: the native File menu sits
beside Edit/View/Window/Help, the Flutter top bar contains no duplicate, and
the single-title-bar chrome keeps the traffic lights centred. Workspace codec,
selected-path preservation, atomic writing, source binding, and lifecycle
behavior are covered by automated tests.

Not done: code signing and notarization. The local build is suitable for
development, but it is not ready for normal distribution because Gatekeeper may
block an unsigned app on another Mac. Release packaging needs an Apple
Developer identity, signing, notarization, and verification on a clean machine.

## Troubleshooting

- `xcrun: error: unable to find utility "xcodebuild"` — step 2 above was
  skipped; `xcode-select -p` should print the Xcode path.
- A permitted folder cannot be read — inspect the security-scope grant and the
  resulting `FileSystemException`. Keep the sandbox enabled so the diagnosis
  follows the same access path as a release build.
