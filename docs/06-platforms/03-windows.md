# Windows

Implemented in source but not yet built, because native verification requires
a Windows machine.

## What exists

`flutter create --platforms windows` generated `windows/`. The native runner
now carries the product name and the platform services Visual MD needs:

- The window title is `Visual MD`, opened at 1280 × 720
  (`windows/runner/main.cpp`).
- Version resource strings — company, description, product name, copyright —
  read `Visual MD`; the internal name and executable stay `visualmd`
  (`windows/runner/Runner.rc`, `windows/CMakeLists.txt`).
- A native Win32 File menu sends workspace commands to Flutter
  (`windows/runner/flutter_window.cpp`,
  `windows/runner/flutter_window.cpp`).
- Workspace replacement uses `ReplaceFileW` with write-through and a backup,
  falling back to `MoveFileExW` for the first save
  (`windows/runner/flutter_window.cpp`).

## Build

On Windows, with Visual Studio and its **Desktop development with C++**
workload installed:

```powershell
flutter doctor            # Visual Studio must show a check
flutter run -d windows
flutter build windows     # output under build\windows\x64\runner\Release
```

Nothing in `lib/` is expected to change. The same `io/` adapter family that
runs on macOS is selected on Windows by the conditional import
(`lib/infrastructure/platform/platform.dart`), and every macOS-only behaviour
is guarded:

| Concern | Windows behaviour | Source |
|---------|-------------------|--------|
| External links | `rundll32 url.dll,FileProtocolHandler <url>` | `lib/infrastructure/io/desktop_links.dart` |
| Security-scoped access | skipped; reads directly | `lib/infrastructure/io/desktop_security_scope.dart` |
| Top bar | plain 44 px bar, 8 px inset (`plainTopBar`) | `lib/infrastructure/platform/platform_io.dart`, `lib/infrastructure/platform/platform_adapters.dart` |
| Window drag | identity — the system title bar stays | `lib/infrastructure/platform/platform_io.dart` |
| Folder drop / picker | `desktop_drop` and `file_selector`, both with Windows implementations | `lib/infrastructure/platform/platform_io.dart`, `lib/infrastructure/platform/platform_io.dart` |
| File commands | native Win32 menu and Ctrl shortcuts | `windows/runner/flutter_window.cpp` |
| Workspace writes | atomic replace with last-good backup | `windows/runner/flutter_window.cpp` |

## Window chrome

Windows keeps its native title bar for now. Hiding it the way macOS does
would also remove the minimise, maximise, and close buttons, which the app
would then have to paint itself. Those painted controls are planned as a
later **top bar actions** slot contributor under the
[Plugin Architecture](../07-roadmap/01-plugin-architecture.md); until then
the chrome stays native.

## Status

Unbuilt. Dart analysis, portable behavior tests, and the web/macOS builds are
green, but they are not a substitute for a Windows build. The first Windows
verification should cover launch, native File commands, folder and Markdown
drop, pickers, link opening, workspace replacement, and restart restoration.
If one of those paths fails, start with the native runner, the two desktop
plugins, and the Windows branches in the IO adapters; the shared tests then
help distinguish platform integration from portable behavior.
