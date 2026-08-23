# Panel Widths

## Purpose and boundary

`PanelWidths` is the reader's remembered geometry for the shelf and outline.
It separates what the reader prefers from what the current window can honour,
so narrowing a window does not overwrite a choice made in a larger room
(`lib/api/layout/panel_widths.dart:3-23`).

It is a framework-free value in the API ring. The shell asks it for effective
widths; the controller owns and persists the preferences.

## Present wiring

The designed widths are 280 px for the shelf and 240 px for the outline. The
shelf may range from 220–520 px and the outline from 200–440 px
(`lib/api/layout/panel_widths.dart:9-15`). These are chrome bounds: enough room
for a useful folder tree or heading list, but never permission for furniture to
take the whole window.

`fromStored` restores each side independently. A missing, non-numeric,
non-finite or out-of-range value falls back only that side to its default
(`lib/api/layout/panel_widths.dart:25-42`,
`lib/api/layout/panel_widths.dart:104-118`). Drag updates pass through
`withShelf` or `withOutline`, which enforce the same bounds
(`lib/api/layout/panel_widths.dart:44-56`).

### Protecting the page

`fitWide` receives the window width and the centre width the page needs. The
remainder is the side-panel budget. When both preferences fit, they are returned
untouched; when they do not, only the room above each panel's minimum is reduced,
in the same proportion on both sides
(`lib/api/layout/panel_widths.dart:58-96`). The reading column therefore wins
without one side panel silently winning over the other.

Compact overlays do not participate in that budget because they sit over the
page. They inherit the same preference but stop 56 px before the opposite edge,
leaving the underlying room visible (`lib/api/layout/panel_widths.dart:17-18`,
`lib/api/layout/panel_widths.dart:98-102`).

## Inputs and outputs

Inputs are two stored strings, proposed shelf or outline widths, or the
available and protected widths for a layout. Outputs are a new `PanelWidths`
value or a fitted `(shelf, outline)` record. The object never mutates.

## Events

None. Pointer and keyboard gestures belong to
[Panel Resize Handle](19-panel-resize-handle.md); persistence belongs to the
[Reader Controller](01-reader-controller.md).

## Lifecycle

One preferred value lives on the controller for the session. A fitted width is
derived on every layout and discarded. The composition root restores both
preferences before constructing the controller (`lib/main.dart:63-80`).

## Failure and recovery

Bad stored values cannot produce an unusable shell: they fall back independently.
An impossibly small wide-layout budget reduces even the panel minima in their
existing proportion rather than overflowing (`lib/api/layout/panel_widths.dart:79-85`).
In normal use the shell changes to compact mode before that case is reached.

The pure rules are covered directly: restoration, bounds, centre protection and
compact clamping (`test/presentation/panel_widths_test.dart:5-49`).

## Transition

Panel widths are global reader preferences rather than workspace fields. A
future per-workspace layout would need an explicit format and migration
decision; it should not appear indirectly in these values.
