# Workspace Actions

## Purpose and boundary

Workspace actions expose the durable lifecycle through application menus,
keyboard shortcuts, and visible feedback. The Flutter API ring owns UI state
and delegates every operation to an application use case. macOS uses the
host's File menu; Windows uses the Visual MD wordmark menu in the reader top
bar. File I/O remains behind application ports on both.

## Present wiring

The platform command contract distinguishes workspace actions from native
reader commands. It carries Open reader sources, Open Workspace, and Open
Sample Library alongside New, Save, Save As, Add Folder, and Add Markdown. The
same channel also carries Settings, search, panel visibility, text size, and
Help selections
(`lib/infrastructure/platform/platform_command.dart`). Desktop hosts send
those selections over one method channel, where they become a typed stream
(`lib/infrastructure/io/desktop_commands.dart`). The channel is bidirectional:
the composition root sends a small capability projection back after controller
changes, so AppKit can validate its own items, check Shelf and Outline, and
name the hidden native window after the current document
(`lib/infrastructure/platform/native_reader_state.dart`,
`lib/infrastructure/io/desktop_commands.dart`). The composition root maps
durable actions to the matching controller method, external links to the
platform opener, and transient surfaces to a small API-owned command stream
(`lib/main.dart`, `lib/api/reader_ui_command.dart`). This translation keeps the
API ring independent of the infrastructure command type.

The Open boundary is typed before it reaches the controller. A
`ReaderSourcePicker` returns folder or Markdown selections behind opaque refs
(`lib/application/ports/reader_source_picker.dart`). The macOS adapter
translates native panel records into those selections and rejects non-Markdown
files defensively (`lib/infrastructure/io/desktop_reader_source_picker.dart`).
An API-level opener then sends each selection through the existing `AddFolder`
or `AddMarkdown` path and prevents a second picker from racing the first
(`lib/api/reader_source_opener.dart`).

The controller treats New and Open Workspace as mutually exclusive opening operations,
updates the active Library only after success, and turns failures into visible
messages (`lib/api/reader_controller.dart`). Save and Save As preserve
the current UI on failure and display the error in the same notice
(`lib/api/reader_controller.dart`).

Flutter `CallbackShortcuts` provides Command shortcuts on macOS and Control
shortcuts elsewhere. The same callbacks back the Windows wordmark menu, while
macOS continues to contribute a native global menu.

The macOS menu is deliberately a reader menu rather than the editor template
Flutter starts with. File includes Close Window; Edit retains Copy and Select
All plus the two search scopes; View exposes panels, text size, and full
screen; Help exposes shortcuts, support, privacy, and the licence registry.
Save and library search remain unavailable until a library exists; document
find, Outline, and text sizing remain unavailable until a document exists.
The Shelf and Outline items carry AppKit checkmarks for their current wide-mode
visibility. Their labels stay stable because the checkmark, not changing copy,
communicates state.
Settings requests the existing Appearance popover through an
`AnchoredMenuController`, so the menu bar never creates a second preferences
model (`macos/Runner/MainFlutterWindow.swift`,
`macos/Runner/Base.lproj/MainMenu.xib`,
`lib/api/widgets/anchored_menu.dart`,
`lib/api/screens/reader_screen.dart`).

## Inputs and outputs

| Action | Shortcut | Result |
|--------|----------|--------|
| New Workspace | Command/Control-N | fresh unbound reading room |
| Open | Command-O on macOS | selected folders and Markdown files added in panel order |
| Open Workspace | Command/Control-Shift-O | selected workspace restored transactionally |
| Open Sample Library | Command-Option-O / Control-Alt-O | bundled sample opened or refreshed without duplicating its root |
| Save | Command/Control-S | current workspace flushed or first file requested |
| Save As | Command/Control-Shift-S | fork written with a new Workspace ID |
| Add Folder | desktop workspace menu | folder appended to the current workspace |
| Add Markdown | desktop workspace menu | standalone Markdown added or resolved |

The native macOS Open panel accepts folders and the supported Markdown
extensions together, permits multiple selection, and reports whether each URL
is a directory before Dart sees it (`macos/Runner/MainFlutterWindow.swift`).
Command-O invokes that reader-source action, Command-Shift-O invokes Open
Workspace, and Command-Option-O invokes the sample. The welcome screen and
native File menu expose those same commands
(`lib/api/screens/reader_screen.dart`,
`macos/Runner/MainFlutterWindow.swift`).

Windows has separate folder and Markdown pickers. Its Visual MD wordmark menu
exposes New, Open Workspace, Add Folder, Add Markdown, Save, and Save As; the
native title bar remains responsible only for the operating-system window
contract (`lib/api/screens/reader_screen.dart`,
`windows/runner/flutter_window.cpp`).

## Events

None. Native menu selections are commands, not domain events.

## Lifecycle

The native macOS menu is installed after its menu system exists, and its method
channel lives for the process. The Windows wordmark menu is rebuilt from the
same long-lived controller as part of the Flutter top bar. The controller
receives menu commands and drops, then notifies widgets after each state
transition. One composition-root listener projects only the current title,
library and document capabilities, and panel visibility to macOS; browser and
Windows adapters deliberately ignore that native-state projection.

## Failure and recovery

Cancelling a native picker is a no-op. A reader-source picker failure becomes a
visible error without disturbing the current Library. Invalid workspace JSON,
unavailable files, and write failures likewise leave the current reading room
usable and render a persistent dismissible error. Missing restored sources
remain visible with reconnect and remove actions.

## Transition

Windows and browsers expose separate file and directory choosers, so the
combined Open interaction is currently contributed only by macOS. Adding it
elsewhere requires a deliberate source-kind choice before invoking the existing
platform pickers; it must not silently reduce Open to files or folders alone.
