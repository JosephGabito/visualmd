# Visual MD

<p align="center">
  <img src="assets/brand/visual-md-logo.png" alt="Visual MD" width="112">
</p>

<p align="center"><strong>Your Markdown, with room to breathe.</strong></p>

<p align="center">
  <a href="https://github.com/JosephGabito/visualmd/actions/workflows/validate.yml"><img src="https://github.com/JosephGabito/visualmd/actions/workflows/validate.yml/badge.svg" alt="Build status"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-2f6f9f" alt="MIT licence"></a>
</p>

Markdown is pleasant to write and strangely tiring to read. It usually lives
inside an editor, a file browser, or a documentation site crowded with tools.
Visual MD is for the part that comes afterward: sitting down with the words.

Open a folder and every Markdown file inside it appears on a shelf, nested
folders included. Choose a document and read it on a measured page with its
outline beside you. Your files stay where they are; there is no account, sync
service, upload pipeline, or analytics collector.

Visual MD is a reader, not an editor. That narrow purpose is the point.

## What it feels like

- **A folder becomes a library.** READMEs come first, numbered files sort
  naturally, and dependency folders stay out of sight.
- **The page stays calm.** Line length follows the active typeface, headings
  keep a real vertical rhythm, and code or tables may use more room without
  stretching the prose.
- **Navigation belongs to the document.** The outline follows your position;
  Markdown links, heading fragments, custom anchors, and footnotes go where
  their author intended.
- **Your reading room can travel.** A small, readable workspace file remembers
  the sources, their order, the open document, and your reading preferences.
- **The interface yields to the text.** The shelf and outline resize on wide
  windows and become overlays when space is tight.

The renderer handles the things that make real technical writing useful:
syntax-highlighted code, GitHub-style tables and task lists, local and remote
images, light/dark picture sources, mathematics, Mermaid diagrams, footnotes,
safe inline HTML, and copying that preserves the authored text.

## Privacy is the default

On desktop, Visual MD reads the files you choose directly from disk. In a
browser, file access stays inside the browser's permission model. Documents are
not sent to a Visual MD server because no such server exists.

Remote images and links can still contact their authored destinations. A theme
that names a font not bundled with the app may also ask the font provider for
it. The four standard typefaces ship with Visual MD and require no network.

## Run it

Visual MD currently runs on the web and macOS. Until signed downloads are
published, the complete reader is available from source.

Install a stable Flutter SDK satisfying the Dart constraint in `pubspec.yaml`,
then:

```sh
flutter pub get
bin/tools/prepare-web-assets.sh
flutter run -d chrome
```

Add `?open=sample` to the browser URL to open the included sample library. On a
Mac with Xcode and CocoaPods installed:

```sh
flutter run -d macos
```

| Platform | Status |
|----------|--------|
| Web | Built and tested in Chrome. Modern browsers can retain folder access; older ones use explicit upload and download fallbacks. |
| macOS | Built and tested with native files, folders, menus, sandboxed access, and drag and drop. Public downloads still require Developer ID signing and notarization. |
| Windows | The project and desktop adapters exist, but the native build has not yet been verified on Windows hardware. |

More detailed setup and troubleshooting live in
[Development Setup](docs/09-contributing/01-dev-setup.md).

## Everyday controls

| Action | Shortcut |
|--------|----------|
| Search this document | <kbd>⌘/Ctrl</kbd> <kbd>F</kbd> |
| Search the library | <kbd>⌘/Ctrl</kbd> <kbd>Shift</kbd> <kbd>F</kbd> |
| Show or hide the shelf | <kbd>⌘/Ctrl</kbd> <kbd>B</kbd> |
| Show or hide the outline | <kbd>⌘/Ctrl</kbd> <kbd>.</kbd> |

The macOS **File** menu creates, opens, and saves workspaces and adds Markdown
files or folders. Shelf menus can reveal a source in Finder, copy its path, or
remove it from the current reading room without deleting the original file.

## Made for reading

Typography here is product behavior, not a finishing layer. The prose column
holds roughly 66 characters of the selected face. Text size is normalized by
the face's x-height, leading follows its measured proportions, and blocks
return running text to the same baseline rhythm. Dark themes preserve the same
hierarchy without dimming the body copy.

Those rules came from typography and legibility research, then from measuring
the actual bundled fonts and rendering real pages. The reasoning, sources, and
tests are collected in the
[presentation guide](docs/04-presentation/README.md).

## Contributing

Visual MD welcomes focused fixes, platform work, themes, documentation, and
careful improvements to the reading experience. Start with
[CONTRIBUTING.md](CONTRIBUTING.md); it leads into the full engineering guide
without requiring you to read the whole architecture before making a useful
change.

The complete local gate is:

```sh
bin/tools/beautipass.sh
```

It formats the authored code, analyzes it, runs the tests and documentation
checks, builds the web and supported native targets, and audits the macOS
bundle when run on a Mac.

For a deeper tour, begin with
[Purpose and Status](docs/00-foundation/01-purpose-and-status.md) and follow the
[documentation library](docs/README.md). The code keeps product rules separate
from Flutter, browser, and operating-system details; an architecture test makes
that boundary executable.

## Licence

Visual MD's source code and documentation are released under the
[MIT License](LICENSE). The Visual MD name and logo identify the official
project; see [Visual MD Name and Logo](TRADEMARKS.md) for fair-use guidance for
forks and modified distributions.

Bundled typefaces retain their SIL Open Font License notices under
`assets/fonts/`. Third-party packages and attributed theme palettes remain
under their respective licences.
