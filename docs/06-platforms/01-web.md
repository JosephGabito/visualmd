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

- Description meta and the iOS web-app title (`web/index.html:21`,
  `web/index.html:26`).
- The tab title, "Visual MD" (`web/index.html:32`).
- A pre-paint background — paper in light, lamplight in dark — so the page
  does not flash white before Flutter draws (`web/index.html:33-36`).

`web/manifest.json` carries the app name, description, icons, and the paper
background used by an installed PWA (`web/manifest.json:2-8`, `:10-32`).

## Launch options

The web adapters expose the URL query as `launchOptions`
(`lib/infrastructure/platform/platform_web.dart:93-95`), and the composition
root interprets the supported keys (`lib/main.dart:245-269`):

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
(`lib/main.dart:222-245`). These options support demos, screenshots, and
typography review; a reader who just lands on the page gets the welcome view.

## Adapters

The web family lives in `lib/infrastructure/web/` and is wired by
`platform_web.dart` (`lib/infrastructure/platform/platform_web.dart:23-103`):
registries for offered sources, a document-level drop listener, modern and
legacy pickers, scanners for browser handles and files, workspace persistence,
and `window.open` for links. Details are in
[Web Adapters](../03-infrastructure/web/README.md). Drops need no
widget wrapper on the web — the whole document is the target
(`lib/infrastructure/platform/platform_web.dart:81-82`) — and the browser owns
the window chrome (`lib/infrastructure/platform/platform_web.dart:84-88`).

Preferences, including the theme choice, live in `localStorage` under keys
prefixed `visualmd.` (`lib/infrastructure/platform/platform_web.dart:90-96`),
so a chosen theme survives a reload of the same origin.

Workspace files prefer the browser File System Access API. Permission-bearing
folder and file handles are retained in IndexedDB by Workspace and source
identity. When that API is unavailable, Open uses a local upload and Save
downloads JSON; background autosave is disabled so the browser never produces
surprise downloads (`lib/infrastructure/platform/platform_web.dart:45-54`).

## Known limits

- The reading, interface and code faces are bundled under `assets/fonts/`
  (`pubspec.yaml:28-57`), so the page does not depend on a network font fetch.
  A user theme may still name an unbundled family, in which case the fallback
  loader can require the network (`lib/api/theme/library_theme.dart:127-152`).
- Relative images in documents do not resolve; only the markdown bytes are
  read off the dropped folder.
- The web build currently offers the built-in themes. It has no reader-owned
  theme folder, so `readThemeDocuments` is empty and the theme menu shows no
  location line (`lib/infrastructure/platform/platform_web.dart:98-103`).
  Writing a theme means running the desktop app — see
  [Creating a Theme](../09-contributing/05-creating-a-theme.md).
- Very large folders are read file by file through browser callbacks. While
  that runs, the welcome view says "Shelving your documents…" on first open
  and a thin progress bar shows when re-opening over an existing library;
  there is no cancel.
- Browsers may revoke or decline a retained handle. The source remains in the
  Workspace and is shown for reconnection rather than being dropped.

These limits are tracked in [Backlog](../07-roadmap/02-backlog.md).
