# Purpose and Status

## Purpose

Visual MD is a markdown reader. Drop one document for a quiet page, or drop a
folder and every markdown inside — nested folders included — appears on the
shelf instantly. You pick a document, read it on a wide page, and move through
it with an outline of its headings. It should feel like a cozy library, not a
terminal.

That is the product's centre: open markdown, arrange it on a shelf, and read
with an outline. New ideas are welcome, but they should strengthen that reading
experience rather than turn the reader into a general-purpose editor.

## Principles

1. **Nothing leaves the machine.** Files are read where they are — in the
   browser on the web, from disk on desktop — and never uploaded. There is no
   server. See [Platforms](../06-platforms/README.md).
2. **The reading path stays small.** The domain, application, presentation, and
   API rings keep the core journey understandable. Optional capabilities can
   grow around it.
3. **Extensions have typed seams.** The planned plugin model uses events,
   extension points, and UI slots so optional features can integrate without
   making the reading path harder to follow. This is direction, not current
   code; see
   [Plugins as Typed Hooks](../08-decisions/0007-plugins-as-typed-hooks.md).
4. **The domain decides, adapters move bytes.** What counts as markdown, how a
   shelf is ordered, where a section starts: all domain, all tested. See
   [Domain Owns Parsing and Shelving](../08-decisions/0003-domain-owns-parsing-and-shelving.md).
5. **Dependencies point inward.** A test keeps this design visible as the code
   changes. See
   [Dependency Direction](03-dependency-direction.md).

## What it does today

“All platforms” below means the capability lives in shared Flutter code. The
build status that follows records where the application has actually been run.

| Capability | Where |
|------------|-------|
| Drop a folder anywhere on the window | web (browser drop), macOS (native drop) |
| Drop one markdown into a Markdowns section above Library | web, macOS |
| Reconcile a direct file with its containing folder by physical source | desktop paths and modern browser file handles; legacy web uploads have no stable identity |
| "Open a folder" picker | web (File System Access API with `<input webkitdirectory>` fallback), macOS (native open panel) |
| Shelf with nested, expandable folders; README first; natural sort | all platforms |
| Reading page, measured to 66 characters of its active face | all platforms |
| Compact windows keep the page full-width and open shelf or outline as one overlay | all platforms |
| Shelf and outline resize independently on wide windows; compact overlays inherit the remembered width | all platforms |
| Outline of headings; click to scroll; follows as you read | all platforms |
| Relative `.md` links navigate within the library; `#anchors` scroll | all platforms |
| Front matter set aside; `title:` used on the shelf | all platforms |
| Paper (light) and lamplight (dark) themes, system-following with a toggle | all platforms |
| Keyboard: ⌘/Ctrl+B shelf, ⌘/Ctrl+. outline | all platforms |
| Search the open document or whole library with ⌘/Ctrl+F and ⌘/Ctrl+Shift+F | all platforms |
| New, Open, Save, and Save As for portable workspace JSON | all platforms; native application menus on desktop |
| Reconnect workspace sources that are unavailable on the current machine | all platforms, subject to the access the platform can grant |
| Bundled sample library so the reader is never empty | all platforms |

## Status as of 2026-08-24

- **Web** — built (`flutter build web --release`), served and screenshotted.
- **macOS** — built and run natively once Xcode 26.6 was installed; dropping a
  folder from Finder works under the app sandbox; the system title bar is
  hidden so the traffic lights share the app's own top bar.
- **Windows** — project scaffolded and named; not yet compiled (needs a
  Windows machine with Visual Studio).
- **Tests** — domain, application, infrastructure, API, presentation, and docs
  suites, plus one architecture test per source file.
- **Distribution** — no packaged downloads or signed builds yet; the project
  currently runs from source.

## Document status

Ten shelves exist in `docs/`, from foundation through domain, application,
infrastructure, presentation, API, platforms, roadmap, and decisions to
contributing; the index is the [Architecture](../README.md).

Every component document cites the code it describes as `path:line`. The docs
suite checks that those references still exist, turning many stale explanations
into an ordinary validation error that can be corrected with the code change.
