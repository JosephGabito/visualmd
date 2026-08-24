# Workspace Actions

## Purpose and boundary

Workspace actions expose the durable lifecycle through native application
menus, keyboard shortcuts, and visible feedback. The Flutter API ring owns UI
state and delegates every operation to an application use case. Desktop uses
the host's File menu, while file I/O remains behind application ports.

## Present wiring

The platform command contract distinguishes Open reader sources from Open
Workspace, alongside New, Save, Save As, Add Folder, and Add Markdown
(`lib/infrastructure/platform/platform_command.dart:1-10`). Desktop hosts send
those selections over one method channel, where they become a typed stream
(`lib/infrastructure/io/desktop_commands.dart:7-30`). The composition root maps
each command to the matching controller method (`lib/main.dart:209-224`).

The Open boundary is typed before it reaches the controller. A
`ReaderSourcePicker` returns folder or Markdown selections behind opaque refs
(`lib/application/ports/reader_source_picker.dart:4-24`). The macOS adapter
translates native panel records into those selections and rejects non-Markdown
files defensively (`lib/infrastructure/io/desktop_reader_source_picker.dart:20-59`).
An API-level opener then sends each selection through the existing `AddFolder`
or `AddMarkdown` path and prevents a second picker from racing the first
(`lib/api/reader_source_opener.dart:13-30`).

The controller treats New and Open Workspace as mutually exclusive opening operations,
updates the active Library only after success, and turns failures into visible
messages (`lib/api/reader_controller.dart:241-287`). Save and Save As preserve
the current UI on failure and display the error in the same notice
(`lib/api/reader_controller.dart:289-311`).

Flutter `CallbackShortcuts` provides Command shortcuts on macOS and Control
shortcuts elsewhere, so keyboard behavior remains available on web while the
desktop menu remains genuinely native.

## Inputs and outputs

| Action | Shortcut | Result |
|--------|----------|--------|
| New Workspace | Command/Control-N | fresh unbound reading room |
| Open | Command-O on macOS | selected folders and Markdown files added in panel order |
| Open Workspace | Command/Control-Shift-O | selected workspace restored transactionally |
| Save | Command/Control-S | current workspace flushed or first file requested |
| Save As | Command/Control-Shift-S | fork written with a new Workspace ID |
| Add Folder | native File menu | folder appended to the current workspace |
| Add Markdown | native File menu | standalone Markdown added or resolved |

The native macOS Open panel accepts folders and the supported Markdown
extensions together, permits multiple selection, and reports whether each URL
is a directory before Dart sees it (`macos/Runner/MainFlutterWindow.swift:52-91`).
Command-O invokes that reader-source action; Command-Shift-O invokes Open
Workspace, so the two concepts do not compete for one chord
(`lib/api/screens/reader_screen.dart:280-308`,
`macos/Runner/MainFlutterWindow.swift:231-266`).

## Events

None. Native menu selections are commands, not domain events.

## Lifecycle

The native menu is installed by the host window after its menu system exists.
Its method channel lives for the process. The controller is constructed once,
receives both menu commands and drops, and notifies widgets after each state
transition.

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
