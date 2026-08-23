# 0002 — Flutter Web First, Then Desktop

Status: Accepted · 2026-08-22

## Context

The product is designed primarily as a desktop reader: dropping a folder is a
desktop gesture, and the reading room is useful as a persistent second window.
At the start of implementation, however, the available development environment
had Chrome and the command-line tools but not full Xcode, Android Studio, or a
Windows toolchain.

Flutter targets macOS and iOS only through a full Xcode install (a large
download), Android through Android Studio, and the web through nothing more
than a browser. The architecture was designed so that the platform is an
adapter; the question was only which adapter to write first.

## Decision

Build and verify on **Flutter web** first, because it needs nothing that is
not already installed and headless Chrome can screenshot it for review.
Treat every platform as an adapter family under `infrastructure/` so the
order of platforms is a scheduling choice, not an architectural one.

Add **macOS** as soon as Xcode is available, **Windows** when a Windows machine
is, and keep mobile and the browser extension on the roadmap.

## Consequences

- The browser adapters came first and are the more intricate ones
  (`package:web` interop for directory entries and `webkitdirectory` inputs).
  The desktop adapters that followed are simpler (`dart:io`) and reuse the
  same registry and port shapes.
- Web stays a first-class target, not a demo: `?open=sample` and `?theme=`
  launch options exist for sharing links and for screenshots.
- The macOS target later built without changes to `domain/` or `application/`;
  its sandboxed Finder drop uses optional, identity-defaulted hooks in `api/`.
  Windows is scaffolded and named but remains unverified on a Windows machine.
- The first implementation fetched fonts at runtime. Visual MD now bundles its
  four primary families and uses Google Fonts only for additional names in a
  user theme; see [Theme Binding](../05-api/06-theme.md).

## Evidence

- Platform selection at compile time: `lib/infrastructure/platform/platform.dart:3-5`.
- Web adapter family: `lib/infrastructure/platform/platform_web.dart:12-60`.
- Desktop adapter family: `lib/infrastructure/platform/platform_io.dart:16-86`.
- Launch options read on the web only: `lib/infrastructure/platform/platform_web.dart:34-36`, `lib/infrastructure/platform/platform_io.dart:55-56`.
- Platform notes: [Web](../06-platforms/01-web.md), [macOS](../06-platforms/02-macos.md), [Windows](../06-platforms/03-windows.md).
