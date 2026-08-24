# Browser Folder Drop

## Purpose and boundary

Turns a folder dragged onto the page into a `FolderRef` the application can
open. It listens on the whole document, so the entire window is the drop
target and the UI does not need a special zone
(`lib/infrastructure/web/browser_folder_drop.dart`). Its boundary ends at
the registry: it registers a `BrowserFolder` handle and emits the resulting
ref; reading the folder is the [Browser Folder Scanner](03-folder-scanner.md)'s
job.

## Present wiring

`listen()` attaches four listeners to `web.document`
(`lib/infrastructure/web/browser_folder_drop.dart`):

| Event | Behaviour | Evidence |
|-------|-----------|----------|
| `dragenter` | `preventDefault`; increments a depth counter and emits `dragging = true` on the first entry | `lib/infrastructure/web/browser_folder_drop.dart` |
| `dragover` | `preventDefault` (required for a drop to be allowed); sets `dropEffect = 'copy'` | `lib/infrastructure/web/browser_folder_drop.dart` |
| `dragleave` | decrements the counter; emits `dragging = false` when it reaches 0, clamping at 0 | `lib/infrastructure/web/browser_folder_drop.dart` |
| `drop` | reset drag state; prefer a modern filesystem handle, then fall back to direct-Markdown or legacy folder classification | `lib/infrastructure/web/browser_folder_drop.dart` |

The depth counter exists because the browser fires `dragenter`/`dragleave`
for every child element the pointer crosses; only the outermost transition
should change the overlay (`lib/infrastructure/web/browser_folder_drop.dart`).

When `getAsFileSystemHandle` is available for a single item, the adapter asks
for that handle during the trusted drop event. A directory becomes a
`HandleDirectory`; a Markdown file becomes a `BrowserMarkdownHandle`. If the
promise is rejected or yields no useful handle, the adapter uses the legacy
values captured during the event
(`lib/infrastructure/web/browser_folder_drop.dart`).

The legacy `_folderFrom` path also runs synchronously, because
`webkitGetAsEntry()` is only reliable during dispatch. It walks the
`DataTransferItemList` (`lib/infrastructure/web/browser_folder_drop.dart`):

- items whose `kind` is not `'file'` are skipped (`lib/infrastructure/web/browser_folder_drop.dart`);
- the **first directory wins** and becomes a `DroppedDirectory` (`lib/infrastructure/web/browser_folder_drop.dart`);
  anything else in the same drop is ignored;
- files are collected as loose `(name, File)` pairs (`lib/infrastructure/web/browser_folder_drop.dart`).

If no directory was dropped, the loose files become a `PickedFiles` named
after the single file, or `'Dropped files'` when there are several
(`lib/infrastructure/web/browser_folder_drop.dart`). `PlatformAdapters`
exposes the resulting folder and drag streams as `folderDrops` and `dragging`
(`lib/infrastructure/platform/platform_web.dart`).

## Inputs and outputs

| Direction | What | Evidence |
|-----------|------|----------|
| in | DOM drag events on `document` | `lib/infrastructure/platform/platform_web.dart` |
| out | `Stream<FolderRef> drops` (broadcast) | `lib/infrastructure/platform/platform_web.dart` |
| out | `Stream<bool> dragging` (broadcast) | `lib/infrastructure/platform/platform_web.dart` |
| side effect | a browser folder handle stored in the registry | `lib/infrastructure/platform/platform_web.dart` |

`drops` is wired to `ReaderController.addFolder` and `dragging` to
`setDragging` in the composition root (`lib/main.dart`). Direct-file
classification is documented separately in [Browser Markdown Drop](04-markdown-drop.md).

## Events

None today. The drop adapter emits Dart streams, not domain events; the use
case that consumes the ref is where `LibraryOpened` would be raised.

## Lifecycle

Constructed with the web `PlatformAdapters` and started immediately by
`..listen()` (`lib/infrastructure/platform/platform_web.dart`). Listeners
are never removed — the adapter lives as long as the page.

## Failure and recovery

- A drop with no `dataTransfer`, no file items, or only non-file items yields
  no source; the overlay still clears before conversion (`lib/infrastructure/platform/platform_web.dart`).
- Mis-nested `dragleave` events cannot leave the counter negative; it is
  clamped at 0 (`lib/infrastructure/platform/platform_web.dart`).
- A browser with neither modern filesystem handles nor `webkitGetAsEntry`
  cannot expose a dropped directory. [Browser Folder Picker](02-folder-picker.md)
  remains available through its own modern and legacy paths.

## Transition

- Multiple directories in one legacy drop could become one library with each
  directory as a top-level shelf; today the first wins (`lib/infrastructure/platform/platform_web.dart`).
- If the reading pane ever accepts drops of its own (images into a note),
  a scoped target can replace the document-level listener, following the
  shape the desktop adapter already has (`lib/infrastructure/io/desktop_folder_drop.dart`).
