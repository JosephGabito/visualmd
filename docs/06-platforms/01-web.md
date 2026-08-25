# Web

The first target, and the one with zero toolchain prerequisites beyond
Flutter and a browser.

## Build and run

```sh
flutter run -d chrome            # develop with hot reload (r / R / q)
flutter build web --release      # output in build/web
cd build/web && python3 -m http.server 8765   # serve the release build
```

The release build is plain static files; any static host serves it.

## Shell page

`web/index.html` keeps the Flutter bootstrap and adds three product details:

- Description meta and the iOS web-app title (`web/index.html`,
  `web/index.html`).
- The tab title, "Visual MD" (`web/index.html`).
- A pre-paint background — paper in light, lamplight in dark — so the page
  does not flash white before Flutter draws (`web/index.html`).

`web/manifest.json` carries the app name, description, icons, and the paper
background used by an installed PWA (`web/manifest.json`, `web/manifest.json`).

## Launch options

The web adapters expose the URL query as `launchOptions`
(`lib/infrastructure/platform/platform_web.dart`), and the composition
root interprets the supported keys (`lib/main.dart`):

| Query | Effect |
|-------|--------|
| `?open=sample` | opens the bundled sample library on load |
| `?theme=<id>` | wears one theme for this run — any id from the theme menu |
| `?theme=light` / `?theme=dark` | shorthand for the two halves of the default pair |
| `?paragraphs=indented` | sets the page solid: indented first lines, no gaps |
| `?paragraphs=spaced` | the default — a gap between paragraphs, no indent |
| `?serif=<family>` | previews one reading face for this run without saving it |

They compose: `?open=sample&theme=nord&paragraphs=indented`. An unknown theme
id is ignored, and launch overrides are not saved
(`lib/main.dart`). These options support demos, screenshots, and
typography review; a reader who just lands on the page gets the welcome view.

## Adapters

The web family lives in `lib/infrastructure/web/` and is wired by
`platform_web.dart` (`lib/infrastructure/platform/platform_web.dart`):
registries for offered sources, a document-level drop listener, modern and
legacy pickers, scanners for browser handles and files, workspace persistence,
and `window.open` for links. Details are in
[Web Adapters](../03-infrastructure/web/README.md). Drops need no
widget wrapper on the web — the whole document is the target
(`lib/infrastructure/platform/platform_web.dart`) — and the browser owns
the window chrome (`lib/infrastructure/platform/platform_web.dart`).

Preferences, including the theme choice, live in `localStorage` under keys
prefixed `visualmd.` (`lib/infrastructure/platform/platform_web.dart`),
so a chosen theme survives a reload of the same origin.

Workspace files prefer the browser File System Access API. Permission-bearing
folder and file handles are retained in IndexedDB by Workspace and source
identity. When that API is unavailable, Open uses a local upload and Save
downloads JSON; background autosave is disabled so the browser never produces
surprise downloads (`lib/infrastructure/platform/platform_web.dart`).

## Known limits

- The reading, interface and code faces are bundled under `assets/fonts/`
  (`pubspec.yaml`), so the page does not depend on a network font fetch.
  A user theme may still name an unbundled family, in which case the fallback
  loader can require the network (`lib/api/theme/library_theme.dart`).
- Relative images resolve through a folder handle, dropped directory, or file
  list already offered to the page. A Markdown file uploaded alone has no
  browser capability for its neighbouring files, so its relative images fall
  back to their alternatives (`lib/infrastructure/web/browser_document_image_loader.dart`).
- Remote images use Flutter's network provider. When a server blocks CanvasKit
  from reading cross-origin bytes, the web build may fall back to an HTML image
  element; loading failure still leaves the authored alternative visible
  (`lib/api/widgets/document_image.dart`).
- The web build currently offers the built-in themes. It has no reader-owned
  theme folder, so `readThemeDocuments` is empty and the theme menu shows no
  location line (`lib/infrastructure/platform/platform_web.dart`).
  Writing a theme means running the desktop app — see
  [Creating a Theme](../09-contributing/05-creating-a-theme.md).
- Very large folders are read file by file through browser callbacks. While
  that runs, the welcome view says "Shelving your documents…" on first open
  and a thin progress bar shows when re-opening over an existing library;
  there is no cancel.
- Browsers may revoke or decline a retained handle. The source remains in the
  Workspace and is shown for reconnection rather than being dropped.

These limits are tracked in [Backlog](../07-roadmap/02-backlog.md).
