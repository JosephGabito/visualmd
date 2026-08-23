# 0006 — Platform Adapters by Conditional Import

Status: Accepted · 2026-08-22

## Context

The web adapters import `package:web` and `dart:js_interop`; the desktop
adapters import `dart:io`, `desktop_drop`, `file_selector` and
`window_manager`. Neither set compiles on the other target. The composition
root needs one name to call — "give me this platform's adapters" — without a
runtime `if` that would still force both sets to compile.

Flutter's own answer is Dart's conditional import/export, which selects a
library at compile time based on which SDK libraries the target supports.

## Decision

`infrastructure/platform/platform.dart` is a single conditional `export`:

- `dart.library.js_interop` → `platform_web.dart`
- `dart.library.io` → `platform_io.dart`
- otherwise → `platform_stub.dart`, which throws `UnsupportedError`

`js_interop` is checked **first**, deliberately: the web toolchain also
reports `dart.library.io` as available (the library exists, it just throws),
so checking `io` first would pick the desktop adapters on the web.

Every family implements `PlatformAdapters`, one interface with everything the
composition root needs: a `FolderScanner`, a folder picker, drop and dragging
streams, an external-link opener, launch options, a drop-region wrapper, the
top-bar geometry, and a window-drag wrapper. `createPlatformAdapters()` is
asynchronous because macOS must ask the window for its title-bar height
before the first frame.

## Consequences

- `main.dart` has no platform conditionals and no platform imports.
- Adding a platform family means one more branch in `platform.dart` and one
  more implementation of the interface. Windows needs neither: it is served by
  the `io` family.
- Platform-specific behaviour *within* a family (macOS title-bar handling,
  sandbox bookmarks) is guarded with `Platform.isMacOS` inside that family,
  never outside it.
- The interface grows by one member each time the UI needs a new platform
  capability (`topBar` and `windowDragRegion` were added for the macOS title
  bar). That is visible growth in one place, which is preferable to scattered
  conditionals.

## Evidence

- The conditional export and its ordering note: `lib/infrastructure/platform/platform.dart:1-5`.
- The interface: `lib/infrastructure/platform/platform_adapters.dart:7-44`.
- The stub: `lib/infrastructure/platform/platform_stub.dart:3-4`.
- Web family: `lib/infrastructure/platform/platform_web.dart:12-60`.
- Desktop family, including the macOS-only title-bar measurement: `lib/infrastructure/platform/platform_io.dart:16-27`, `lib/infrastructure/platform/platform_io.dart:61-73`.
- The composition root awaiting it: `lib/main.dart:21`.
- Platform packages confined to infrastructure by test: `test/architecture/dependency_rules_test.dart:30-33`.
