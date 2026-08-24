# Platforms

Visual MD carries the same library, document, and reading behavior to every
target. The platform layer supplies the parts that genuinely differ: how a
folder is chosen, how files are read, how links open, and who owns the window.

At compile time, `lib/infrastructure/platform/platform.dart` selects the
appropriate adapter family. [Platform Adapters](../03-infrastructure/01-platform-adapters.md)
explains the shared object returned to the composition root.

## Current support

| Document | Current status |
|----------|----------------|
| [Web](01-web.md) | Built, served, and verified in Chrome |
| [macOS](02-macos.md) | Built and launched; Finder folder drop verified |
| [Windows](03-windows.md) | Project scaffold and desktop adapter path exist; a build on Windows has not yet been verified |

Windows support is therefore implementation work in progress, not a confirmed
release target yet. The platform document records what is shared and what still
needs a Windows machine.

## Capability map

| Capability | Web | macOS | Windows |
|------------|-----|-------|---------|
| Drop a folder | Document-level DOM drop (`lib/infrastructure/web/browser_folder_drop.dart`) | `desktop_drop` widget wrapper (`lib/infrastructure/platform/platform_io.dart`) | Intended to use the desktop adapter; unverified |
| Drop one Markdown file | Direct stream; physical identity depends on the browser handle | Direct stream with normalized physical identity | Intended to use the desktop adapter; unverified |
| Pick a folder | `<input webkitdirectory>` | Native open panel through `file_selector` | Intended to use the desktop adapter; unverified |
| Open an external link | `window.open` (`lib/infrastructure/platform/platform_web.dart`) | `open` (`lib/infrastructure/io/desktop_links.dart`) | `rundll32` implementation present (`lib/infrastructure/io/desktop_links.dart`) |
| Restore source access | Browser permissions and optional persisted handles | Security-scoped bookmarks (`lib/infrastructure/io/desktop_security_scope.dart`) | No sandbox scope expected; unverified |
| Window chrome | Owned by the browser (`lib/infrastructure/platform/platform_web.dart`) | Hidden system title bar, 84 px inset, draggable Visual MD top bar (`lib/infrastructure/platform/platform_io.dart`, `lib/infrastructure/platform/platform_io.dart`) | System title bar implementation present (`lib/infrastructure/platform/platform_io.dart`) |
| Launch options | URL query (`lib/infrastructure/platform/platform_web.dart`) | None (`lib/infrastructure/platform/platform_io.dart`) | None |

## How the selection stays small

`platform.dart` uses conditional exports, checking browser interop before
`dart:io`. Each selected file defines `createPlatformAdapters()` and returns a
`PlatformAdapters` value (`lib/infrastructure/platform/platform_adapters.dart`).
The composition root awaits it once, then passes those capabilities to the use
cases and UI (`lib/main.dart`, `lib/main.dart`, `lib/main.dart`).

The platform can contribute a drop region, top bar, or window drag region, but
the document model and use cases remain shared. These optional hooks have
identity defaults, so the browser and desktop can use the same composition path
without pretending their windows behave alike (`lib/api/app.dart`).

To support another target, add an infrastructure adapter family and provide a
`PlatformAdapters` implementation. [Adding a Platform](../09-contributing/03-adding-a-platform.md)
walks through the existing seams and the evidence expected for a new target.
