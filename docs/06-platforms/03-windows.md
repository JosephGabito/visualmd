# Windows

Visual MD is a verified Windows desktop target. Flutter compiles the shared
Dart application ahead of time, while the Win32 runner owns the native window,
file dialogs, and atomic workspace replacement. Flutter owns the reader's
workspace menu and keyboard shortcuts.

## What is verified

The 1.0.0 x64 release was built with Flutter 3.47.1 and Visual Studio 2022 on a
Windows 11 ARM virtual machine. Windows ran the x64 executable through its
normal emulation layer. The app launched, opened the bundled sample library,
retained the designed fonts and reading measure, used the native folder picker,
scanned a local folder recursively, and rendered its Markdown.

That establishes the compiler, Flutter engine, native plugins, bundled assets,
and core local-reading path. Drag/drop, external-link launch, live source
refresh, saved-workspace restoration, Store update, and uninstall remain
explicit clean-machine checks rather than inferred claims.

## Native host

The runner carries the product name and the platform services the reader needs:

- The window title is `Visual MD`, opened at 1280 × 800
  (`windows/runner/main.cpp`).
- Version resources name the product and executable
  (`windows/runner/Runner.rc`, `windows/CMakeLists.txt`).
- The Visual MD wordmark opens the workspace menu in the reader top bar
  (`lib/api/screens/reader_screen.dart`).
- Windows 11's native caption takes the active Visual MD top-bar and ink
  colours while retaining the real system controls
  (`windows/runner/flutter_window.cpp`, `lib/api/app.dart`).
- Workspace replacement uses `ReplaceFileW` with write-through and a backup,
  falling back to `MoveFileExW` for the first save
  (`windows/runner/flutter_window.cpp`).

## Build and audit

Install Visual Studio with **Desktop development with C++**, then run:

```powershell
flutter pub get --enforce-lockfile
flutter analyze
flutter test
flutter build windows --release
bin/tools/validate-windows-bundle.ps1 -ExpectedVersion 1.0.0
```

The output is `build\windows\x64\runner\Release`. `visualmd.exe` is only the
entry point; the Flutter engine, plugin DLLs, AOT application, fonts, and data
beside it are one inseparable bundle. The validator requires those files,
licence notices, release metadata, and the absence of debug symbols.

## Platform behavior

| Concern | Windows behavior | Source |
|---------|------------------|--------|
| External links | `rundll32 url.dll,FileProtocolHandler <url>` | `lib/infrastructure/io/desktop_links.dart` |
| Security-scoped access | skipped; reads directly | `lib/infrastructure/io/desktop_security_scope.dart` |
| Top bar | plain 52 px bar, 8 px inset | `lib/infrastructure/platform/platform_io.dart` |
| Window drag | identity; the system title bar stays | `lib/infrastructure/platform/platform_io.dart` |
| Caption colour | active top-bar background and ink through DWM | `lib/api/app.dart`, `windows/runner/flutter_window.cpp` |
| Folder drop / picker | Windows implementations of `desktop_drop` and `file_selector` | `lib/infrastructure/platform/platform_io.dart` |
| Workspace commands | Visual MD wordmark menu and Ctrl shortcuts | `lib/api/screens/reader_screen.dart` |
| Workspace writes | atomic replace with last-good backup | `windows/runner/flutter_window.cpp` |

## Distribution

The public Windows package is MSIX and its only distribution channel is the
Microsoft Store. MSIX carries the complete Flutter bundle, gives Windows a
stable package identity, installs and removes cleanly, and lets the Store
deliver updates. Microsoft signs the package after certification, so neither a
commercial certificate nor an unsigned public download belongs in this
repository (`windows/store/AppxManifest.xml`).

Pull requests and `main` build an MSIX with an unmistakably non-production
identity, unpack it again, and audit its manifest and payload. The real package
must be built with the three exact identity values Partner Center assigns after
the product name is reserved. The package script refuses to invent them
(`.github/workflows/validate.yml`,
`bin/tools/package-windows-store.ps1`,
`bin/tools/validate-windows-store-package.ps1`).

The production identity and Partner Center submission remain release-operator
work. They are deliberately not presented as contributor setup.

## Window chrome

Windows keeps its native title bar, preserving minimize, maximize, close,
resizing, Snap Layouts, and the system accessibility contract. On Windows 11,
`DwmSetWindowAttribute` tints that caption with the active Visual MD top-bar
and ink colours, so the native controls belong to the same room without being
reimplemented. Workspace commands live behind the Visual MD wordmark inside
the designed top bar, so the generic Win32 File strip does not split the
product chrome into two unrelated interfaces (`lib/api/app.dart`,
`lib/infrastructure/io/desktop_commands.dart`,
`windows/runner/flutter_window.cpp`).
