# Browser Folder Picker

## Purpose and boundary

The “Open a folder” button on the web. Capable browsers provide a durable File
System Access handle; other browsers fall back to
`<input type="file" webkitdirectory>`. Both paths end at the registry and return
the same `FolderRef` shape to the application
(`lib/infrastructure/web/browser_folder_picker.dart`).

## Present wiring

`pick()` first calls `pickDirectoryHandle`. A selected handle becomes a
`HandleDirectory`, cancellation returns `null`, and an unsupported API falls
through to `_pickLegacy`
(`lib/infrastructure/web/browser_folder_picker.dart`).

The legacy path (`lib/infrastructure/web/browser_folder_picker.dart`):

1. Creates a hidden `<input>` with `type = 'file'`, `webkitdirectory = true`
   and `display: none`, and appends it to `document.body` (`lib/infrastructure/web/browser_folder_picker.dart`).
2. Listens for `change` (a folder was chosen) and `cancel` (the dialog was
   dismissed), then programmatically clicks the input (`lib/infrastructure/web/browser_folder_picker.dart`).
3. `finish` removes the input and completes the future exactly once, guarded
   by `completer.isCompleted` (`lib/infrastructure/web/browser_folder_picker.dart`).

`_folderFrom` (`lib/infrastructure/web/browser_folder_picker.dart`)
turns the `FileList` into a `PickedFiles` handle:

| Step | Rule | Evidence |
|------|------|----------|
| name | the first segment of the first file's `webkitRelativePath` — the folder the reader picked | `lib/infrastructure/web/browser_folder_picker.dart` |
| paths | `webkitRelativePath` with that first segment removed, joined with `/` | `lib/infrastructure/web/browser_folder_picker.dart` |
| skip | entries whose relative path has fewer than two segments | `lib/infrastructure/web/browser_folder_picker.dart` |
| register | `PickedFiles(name, files)` into the `BrowserFolderRegistry` | `lib/infrastructure/web/browser_folder_picker.dart` |

The resulting ref is what `PlatformAdapters.pickFolder()` resolves to
(`lib/infrastructure/platform/platform_web.dart`), and the controller
opens it straight away (`lib/api/reader_controller.dart`).

## Inputs and outputs

| Direction | What | Evidence |
|-----------|------|----------|
| in | a user gesture (the browser requires one to open the dialog) | `lib/api/reader_controller.dart` |
| in | a modern directory handle or legacy `FileList` | `lib/api/reader_controller.dart` |
| out | `Future<FolderRef?>` — `null` on cancel or empty selection | `lib/api/reader_controller.dart` |
| side effect | a `HandleDirectory` or `PickedFiles` stored in the registry | `lib/api/reader_controller.dart` |

Every file in the folder is listed up front by the browser, including
non-Markdown; filtering is the [Browser Folder Scanner](03-folder-scanner.md)'s
job. It applies the domain rule before reading any bytes.

## Events

None. The picker offers a ref; `AddFolder` owns the resulting library change.

## Lifecycle

The modern path returns one permission-bearing handle. The legacy path creates
a fresh input per call and removes it as soon as the dialog resolves (`lib/api/reader_controller.dart`).
The registry keeps the selected handle for the current page session; workspace
persistence may also store a modern handle in IndexedDB.

## Failure and recovery

- Cancel: the modern or legacy picker completes with `null`; the controller
  does nothing (`lib/api/reader_controller.dart`). Older browsers without
  `cancel` leave the future pending until the page is reloaded — harmless,
  since a new click creates a new input.
- An empty `FileList` or one with no path containing a folder segment
  resolves `null` (`lib/api/reader_controller.dart`).
- Very large folders are listed by the browser before `change` fires; that
  delay is outside the adapter's control.

## Transition

File System Access already provides the durable path where supported. The
fallback remains important for browsers that omit it; improvements should keep
both paths producing the same application-facing reference.
