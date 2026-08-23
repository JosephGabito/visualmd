# Workspace Actions

## Purpose and boundary

Workspace actions expose the durable lifecycle through native application
menus, keyboard shortcuts, and visible feedback. The Flutter API ring owns UI
state and delegates every operation to an application use case. Desktop uses
the host's File menu, while file I/O remains behind application ports.

## Present wiring

The platform command contract names New, Open, Save, Save As, Add Folder, and
Add Markdown (`lib/infrastructure/platform/platform_command.dart:1-9`). Desktop
hosts send those selections over one method channel, where they become a typed
stream (`lib/infrastructure/io/desktop_commands.dart:7-28`). The composition
root maps each command to the matching controller method
(`lib/main.dart:201-220`).

The controller treats New and Open as mutually exclusive opening operations,
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
| Open Workspace | Command/Control-O | selected workspace restored transactionally |
| Save | Command/Control-S | current workspace flushed or first file requested |
| Save As | Command/Control-Shift-S | fork written with a new Workspace ID |
| Add Folder | native File menu | folder appended to the current workspace |
| Add Markdown | native File menu | standalone Markdown added or resolved |

## Events

None. Native menu selections are commands, not domain events.

## Lifecycle

The native menu is installed by the host window after its menu system exists.
Its method channel lives for the process. The controller is constructed once,
receives both menu commands and drops, and notifies widgets after each state
transition.

## Failure and recovery

Cancelling a native picker is a no-op. Invalid workspace JSON, unavailable
files, and write failures leave the current reading room usable and render a
persistent dismissible error. Missing restored sources remain visible with
reconnect and remove actions.

## Transition

Future File actions should extend the typed platform command contract and use
cases together. On desktop they belong in the native application menu; web can
continue to expose the same use cases through shortcuts or suitable in-window
controls.
