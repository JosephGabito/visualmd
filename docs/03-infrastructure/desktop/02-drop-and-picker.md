# Desktop Drop, Picker and Links

## Purpose and boundary

Three small adapters let the desktop offer a folder or markdown, or hand off a
link:

| Adapter | Does | Source |
|---------|------|--------|
| `DesktopFolderDrop` | folder and direct-markdown drops become opaque refs | `lib/infrastructure/io/desktop_folder_drop.dart` |
| `DesktopFolderPicker` | the native "choose a folder" dialog | `lib/infrastructure/io/desktop_folder_picker.dart` |
| `DesktopReaderSourcePicker` | macOS Open records become typed folder or Markdown refs | `lib/infrastructure/io/desktop_reader_source_picker.dart` |
| `openWithSystem` | a URL or local path goes to its system handler | `lib/infrastructure/io/desktop_links.dart` |

All three stop at the registry or the OS; none reads a file. Their boundary
with the UI is a wrapper function and three streams, so the API never imports
`desktop_drop` or `file_selector`.

## Present wiring

**Drop.** Desktop drop arrives through a widget, not a document listener, so
`wrap(child)` returns a `DropTarget` around whatever the UI passes in
(`lib/infrastructure/io/desktop_folder_drop.dart`). The composition root
applies it to the whole screen via `PlatformAdapters.dropRegion`
(`lib/infrastructure/platform/platform_io.dart`, `lib/main.dart`).

| Callback | Behaviour | Evidence |
|----------|-----------|----------|
| `onDragEntered` | `dragging = true` | `lib/main.dart` |
| `onDragExited` | `dragging = false` | `lib/main.dart` |
| `onDragDone` | reset drag state; classify a direct markdown first; otherwise emit a folder ref | `lib/main.dart` |

Exactly one non-directory Markdown file is registered with stable local source
identity and emitted on `markdownDrops` (`lib/main.dart`, `lib/main.dart`). `_folderFrom`
(`lib/main.dart`) handles the remaining shapes: the first item that is a
`DropItemDirectory` — or whose path `FileSystemEntity.isDirectorySync` — wins
and becomes a `LocalDirectory`, carrying `extraAppleBookmark` for the sandbox
(`lib/main.dart`). Otherwise every item is a loose file and the drop becomes a
`LocalFiles` named after the single file or `'Dropped files'` (`lib/main.dart`).

**Picker.** `pick()` calls `file_selector`'s `getDirectoryPath` with the
confirm button labelled "Open library", returns `null` on cancel, and
otherwise registers a `LocalDirectory(path)` with no bookmark and a normalised
session identity (`lib/infrastructure/io/desktop_folder_picker.dart`). No bookmark is
needed: the open panel itself grants the sandboxed app access to the chosen
folder (`lib/infrastructure/io/desktop_folder_picker.dart`).

**Open.** macOS contributes a mixed-source picker because `NSOpenPanel` can
select directories and files together. Dart validates each native record,
registers its path in the matching local registry, and returns only opaque
folder or Markdown selections
(`lib/infrastructure/io/desktop_reader_source_picker.dart`). Other
desktop families leave the capability absent rather than pretending a
file-only or folder-only dialog is the same interaction
(`lib/infrastructure/platform/platform_io.dart`).

**System handoff.** `openWithSystem` shells out per OS: `open` on macOS, `rundll32
url.dll,FileProtocolHandler` on Windows, `xdg-open` elsewhere
(`lib/infrastructure/io/desktop_links.dart`). External links and the
custom-theme directory share this handoff; their callers decide what target is
appropriate (`lib/infrastructure/platform/platform_io.dart`,
`lib/infrastructure/platform/platform_io.dart`).

## Inputs and outputs

| Adapter | In | Out |
|---------|----|-----|
| drop | `DropDoneDetails.files` (`List<DropItem>`) | folder, markdown and dragging streams — `lib/infrastructure/io/desktop_folder_drop.dart` |
| picker | a user gesture | `Future<FolderRef?>` |
| Open | native folder/file records | typed opaque reader-source selections |
| system handoff | a URL or local path | a child process; result ignored |

## Events

None. The adapters offer refs and drag state; `AddFolder` and `AddMarkdown` own
the corresponding library changes.

## Lifecycle

Drop and picker are created with the desktop `PlatformAdapters`
(`lib/infrastructure/platform/platform_io.dart`). The drop adapter's
broadcast stream controllers live for the process; the `DropTarget` widget is
rebuilt with the UI but the adapter is not.

## Failure and recovery

- An empty drop (no items, or an item that is neither a directory nor a
  file) emits nothing; the drag state is still reset first
  (`lib/infrastructure/io/desktop_folder_drop.dart`).
- Picker cancel yields `null`; the controller ignores it
  (`lib/api/reader_controller.dart`).
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
