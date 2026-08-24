# Panel Resize Handle

## Purpose and boundary

`PanelResizeHandle` is the narrow seam between a side panel and the page. It
turns pointer, keyboard and accessibility actions into relative width changes,
without owning the width or knowing anything about the panel's contents
(`lib/api/widgets/panel_resize_handle.dart`).

It is a chrome primitive in the API ring. The [Shell](02-shell.md) supplies
controller callbacks; [Panel Widths](18-panel-widths.md) supplies the rules.

## Present wiring

The hit area is 7 px wide and the keyboard step is 16 px
(`lib/api/widgets/panel_resize_handle.dart`). Its resting rule is the
ordinary panel border. Hover or focus thickens it to 2 px and changes it to the
theme accent over 100 ms (`lib/api/widgets/panel_resize_handle.dart`,
`lib/api/widgets/panel_resize_handle.dart`). The mouse cursor becomes a
column-resize cursor (`lib/api/widgets/panel_resize_handle.dart`).

Physical movement is translated by side: moving the shelf's right edge right
makes the shelf wider; moving the outline's left edge right makes the outline
narrower (`lib/api/widgets/panel_resize_handle.dart`).

The gestures are:

| Gesture | Result |
|---------|--------|
| Horizontal drag | Preview every delta; persist once when the drag ends |
| Double-click | Restore that panel's designed width |
| Left / right arrow | Move the physical seam by one 16 px step and persist |
| Home | Restore the designed width |

The keyboard mapping is in `_onKeyEvent`
(`lib/api/widgets/panel_resize_handle.dart`); pointer focus, dragging and
double-click are wired together at `lib/api/widgets/panel_resize_handle.dart`. `DragStartBehavior.down` keeps
the seam under the pointer rather than losing the touch-slop distance.

## Inputs and outputs

Inputs are the panel's name, side and current width, plus `onResizeBy`,
`onCommit` and `onReset` callbacks (`lib/api/widgets/panel_resize_handle.dart`).
The resize output is a signed change in the panel's width, not an absolute
screen coordinate.

## Events

The handle publishes no application event. Its callbacks update and persist a
reader preference through the controller. Pointer-down claims focus before the
gesture arena resolves, so the same seam is immediately ready for arrow keys
(`lib/api/widgets/panel_resize_handle.dart`).

## Lifecycle

The widget keeps only hover and focus state. Its private `FocusNode` is disposed
with the handle (`lib/api/widgets/panel_resize_handle.dart`). The handle
is mounted only in the wide shell; compact overlays retain their divider and
have no resizing interaction (`lib/api/screens/reader_screen.dart`,
`lib/api/screens/reader_screen.dart`).

## Failure and recovery

The handle cannot create a harmful width because every preview passes through
`PanelWidths`. Assistive technology receives the label, current pixel value,
next larger and next smaller values, and increase/decrease actions
(`lib/api/widgets/panel_resize_handle.dart`).

Widget tests drag both physical seams, exercise keyboard movement and
double-click reset, and verify compact mode contains no handle
(`test/presentation/reader_chrome_test.dart`,
`test/presentation/reader_chrome_test.dart`).

## Transition

Touch devices currently use the same 7 px seam on wide layouts. If a tablet
target needs a larger hit area, the visible rule should stay one pixel while
the gesture region grows; the visual border must not become heavy furniture.
