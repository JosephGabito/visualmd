# Desktop Drop, Picker and Links

## Purpose and boundary

Three small adapters let the desktop offer a folder or markdown, or hand off a
link:

| Adapter | Does | Source |
|---------|------|--------|
| `DesktopFolderDrop` | folder and direct-markdown drops become opaque refs | `lib/infrastructure/io/desktop_folder_drop.dart:14-28` |
| `DesktopFolderPicker` | the native "choose a folder" dialog | `lib/infrastructure/io/desktop_folder_picker.dart:6-8` |
| `openWithSystem` | a clicked URL goes to the default browser | `lib/infrastructure/io/desktop_links.dart:3-4` |

All three stop at the registry or the OS; none reads a file. Their boundary
with the UI is a wrapper function and three streams, so the API never imports
`desktop_drop` or `file_selector`.

## Present wiring

**Drop.** Desktop drop arrives through a widget, not a document listener, so
`wrap(child)` returns a `DropTarget` around whatever the UI passes in
(`lib/infrastructure/io/desktop_folder_drop.dart:30-58`). The composition root
applies it to the whole screen via `PlatformAdapters.dropRegion`
(`lib/infrastructure/platform/platform_io.dart:95-96`, `lib/main.dart:247-255`).

| Callback | Behaviour | Evidence |
|----------|-----------|----------|
| `onDragEntered` | `dragging = true` | `:31` |
| `onDragExited` | `dragging = false` | `:32` |
| `onDragDone` | reset drag state; classify a direct markdown first; otherwise emit a folder ref | `:33-54` |

Exactly one non-directory Markdown file is registered with stable local source
identity and emitted on `markdownDrops` (`:35-45`, `:58-67`). `_folderFrom`
(`:71-85`) handles the remaining shapes: the first item that is a
`DropItemDirectory` — or whose path `FileSystemEntity.isDirectorySync` — wins
and becomes a `LocalDirectory`, carrying `extraAppleBookmark` for the sandbox
(`:73-77`). Otherwise every item is a loose file and the drop becomes a
`LocalFiles` named after the single file or `'Dropped files'` (`:78-84`).

**Picker.** `pick()` calls `file_selector`'s `getDirectoryPath` with the
confirm button labelled "Open library", returns `null` on cancel, and
otherwise registers a `LocalDirectory(path)` with no bookmark and a normalised
session identity (`lib/infrastructure/io/desktop_folder_picker.dart:13-21`). No bookmark is
needed: the open panel itself grants the sandboxed app access to the chosen
folder (`lib/infrastructure/io/desktop_folder_picker.dart:6-7`).

**Links.** `openWithSystem` shells out per OS: `open` on macOS, `rundll32
url.dll,FileProtocolHandler` on Windows, `xdg-open` elsewhere
(`lib/infrastructure/io/desktop_links.dart:4-12`). The controller decides what
is external (`lib/api/reader_controller.dart:396-434`); this adapter only opens
it.

## Inputs and outputs

| Adapter | In | Out |
|---------|----|-----|
| drop | `DropDoneDetails.files` (`List<DropItem>`) | folder, markdown and dragging streams — `lib/infrastructure/io/desktop_folder_drop.dart:20-28` |
| picker | a user gesture | `Future<FolderRef?>` |
| links | a URL string | a child process; result ignored |

## Events

None. The adapters offer refs and drag state; `AddFolder` and `AddMarkdown` own
the corresponding library changes.

## Lifecycle

Drop and picker are created with the desktop `PlatformAdapters`
(`lib/infrastructure/platform/platform_io.dart:42-50`). The drop adapter's
broadcast stream controllers live for the process; the `DropTarget` widget is
rebuilt with the UI but the adapter is not.

## Failure and recovery

- An empty drop (no items, or an item that is neither a directory nor a
  file) emits nothing; the drag state is still reset first
  (`lib/infrastructure/io/desktop_folder_drop.dart:33-54`).
- Picker cancel yields `null`; the controller ignores it
  (`lib/api/reader_controller.dart:219-225`).
- `Process.run` failures (no `xdg-open` on a minimal Linux) are awaited but
  not surfaced; the link simply does not open.
- A drop whose bookmark the sandbox refuses fails later, in the scanner, as a
  read error — see [macOS Sandbox](04-macos-sandbox.md).

## Transition

- `desktop_drop` also delivers *file promises* (drags from Electron apps)
  into a temporary folder inside the container, with `fromPromise = true`;
  those work today because the path is readable, but the original location is
  unknown and could not be remembered.
- A `url_launcher`-style plugin would replace the shell-outs if a platform
  without a CLI opener (mobile) joins the desktop family.
