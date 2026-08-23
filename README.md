# Visual MD

Visual MD is a local-first reader that makes Markdown feel like a small,
beautiful library. Open one document for a quiet reading page, or open a folder
and browse every Markdown file inside it from a familiar shelf.

The project is built around a simple idea: reading technical material should
feel as considered as reading a good book. Line length, vertical rhythm,
headings, code, tables, themes, search, and navigation all serve that goal.

## A reading room for your files

Visual MD reads files where they live. There is no account, server, upload
pipeline, or analytics service. On desktop it reads directly from disk; on the
web it uses files that you choose in the browser.

Today you can:

- open one Markdown file or any number of folders;
- browse nested folders in README-first, natural order;
- follow a document through its heading outline;
- search the open document or every Markdown file in the library;
- navigate relative Markdown links and in-page anchors;
- resize the shelf and outline without squeezing the reading page;
- choose light and dark reading themes, type size, and paragraph style; and
- save the whole reading room as a portable `.visualmd-workspace.json` file.

A file opened on its own appears under **Markdowns**. If you later add a folder
that contains it, Visual MD moves the same document into that folder's tree and
keeps it open. Workspaces remember this source order, the active document, and
your reading choices.

## See it in five minutes

Visual MD currently uses Dart `^3.13.1`. The project is developed with Flutter
3.47.1 on the stable channel.

```sh
flutter pub get
flutter run -d chrome
```

Add `?open=sample` to the browser URL to open the bundled sample library. For a
native macOS window, install Xcode and run:

```sh
flutter run -d macos
```

The fuller setup guide explains Xcode selection, hot reload, build locations,
and useful launch options in [Development Setup](docs/09-contributing/01-dev-setup.md).

## What is ready today

Visual MD is under active development and does not have packaged downloads yet.
Running it from source gives you the complete reader.

| Platform | Current state |
|----------|---------------|
| Web | Builds and runs. Modern browsers can retain workspace handles; other browsers use explicit upload and download fallbacks. |
| macOS | Builds and runs, including native files, folders, menus, and drag and drop. Distribution signing is not set up yet. |
| Windows | The Flutter project is scaffolded, but the native build has not yet been verified on Windows hardware. |

Relative images are not resolved yet, tables are not fully aligned to the
reader's baseline rhythm, and Windows remains the largest unverified platform.
The [Backlog](docs/07-roadmap/02-backlog.md) records these gaps alongside the
features that are already complete.

## Everyday controls

- `Command/Ctrl-F` searches the open document.
- `Command/Ctrl-Shift-F` searches the whole library.
- `Command/Ctrl-B` opens or closes the shelf.
- `Command/Ctrl-.` opens or closes the outline.
- The native **File** menu creates, opens, and saves workspaces and adds files
  or folders.

Workspaces use a documented, versioned JSON format. Missing sources stay in the
workspace so they can be reconnected instead of silently disappearing. See
[Workspace Persistence](docs/03-infrastructure/03-workspace-persistence.md) for
the format, platform behavior, and recovery model.

## How the code stays understandable

Visual MD separates reading rules from the tools used to reach the file system,
browser, and screen:

```text
lib/
├── domain/          Documents, libraries, workspaces, and their rules
├── application/     User actions and the capabilities they need
├── presentation/    Framework-free theme and typography contracts
├── api/             Flutter widgets, rendering, and the reader shell
├── infrastructure/  Markdown, storage, web, and desktop adapters
└── main.dart        The place where those parts are connected
```

Dependencies point toward the product rules, while platform details stay at the
edge. This keeps the same reading behavior usable across web and desktop, and
an architecture test checks that the boundaries remain true.

You do not need to read the entire architecture handbook before making sense of
the project. Start with [Purpose and Status](docs/00-foundation/01-purpose-and-status.md),
then use the guided map in [the documentation library](docs/README.md) to follow
the part you care about.

## Contributing

Visual MD is being prepared for open-source collaboration while its core reader
is still taking shape. If you are exploring the code now, begin with
[Contributing](docs/09-contributing/README.md). It connects setup, testing,
documentation, platforms, and themes without assuming prior Flutter knowledge.

The three maintenance commands are the shortest route to a clean change:

```sh
bin/tools/validate.sh       # check formatting, analysis, tests, docs, and builds
bin/tools/beautify.sh       # format authored Dart and Swift
bin/tools/beautipass.sh     # format, then run the complete validation
```

[AGENTS.md](AGENTS.md) contains the deeper engineering and typography guidance
used while developing the project. It is detailed because the reader's visual
quality depends on decisions that can be explained, measured, and revisited.

## Licensing

The application does not yet have an open-source licence. Until one is added,
the source is available for review but no open-source permissions are granted.
Bundled typefaces keep their SIL Open Font License notices under `assets/fonts/`.
