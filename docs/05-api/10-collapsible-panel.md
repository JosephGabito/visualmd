# Collapsible Panel

## Purpose and boundary

`CollapsiblePanel` is how a side panel leaves and comes back: it slides out of
the way instead of vanishing. It owns the animation and the clipping, and
nothing about what is inside it — the [Shelf Panel](03-shelf-panel.md) and the
[Outline Panel](05-outline-panel.md) are handed to it as children and are never
told they are moving.

It is a widget in the API ring, used by the [Shell](02-shell.md).

## Present wiring

A `TweenAnimationBuilder<double>` drives a single value between 0 and 1 as
`visible` changes (`lib/api/widgets/collapsible_panel.dart:30-33`), over 180 ms
of `Curves.easeOutCubic`: long enough to follow with the eye, short enough not
to wait for.

Three things happen to that value:

| What | How | Where |
|---|---|---|
| The space it takes | `Align(widthFactor: t)` inside a `ClipRect`, so the row gives the width back to the page as it shrinks | `lib/api/widgets/collapsible_panel.dart:36-41` |
| Which way it goes | The `Align` is pinned to the edge the panel lives against — `centerRight` for a left panel, `centerLeft` for a right one — so the *far* side is what gets clipped and it reads as sliding out rather than squashing | `lib/api/widgets/collapsible_panel.dart:38-40` |
| How it dims | Opacity eased from the same value, so it is on its way out before it fades | `lib/api/widgets/collapsible_panel.dart:42-44` |

The panel keeps its full width the entire time, inside a `SizedBox`
(`lib/api/widgets/collapsible_panel.dart:45`). This is the part that matters:
if the child were allowed to narrow with the container, every row of the shelf
would re-wrap on every frame and the panel would visibly squash. Only the
space it occupies changes.

At rest and invisible it collapses to `SizedBox.shrink()`
(`lib/api/widgets/collapsible_panel.dart:35`), so a hidden panel costs nothing.

The `child` is passed through the builder rather than rebuilt inside it
(`lib/api/widgets/collapsible_panel.dart:50`), so the panel's contents are
built once and only the wrapper animates.

## Inputs and outputs

| In | Type | Meaning |
|---|---|---|
| `visible` | `bool` | Where the animation is heading |
| `width` | `double` | The panel's own width, held throughout |
| `side` | `PanelSide` | `left` or `right` — the edge it is anchored to (`lib/api/widgets/collapsible_panel.dart:3-4`) |
| `child` | `Widget` | The panel |

Out: nothing. It reports no state; `visible` is owned by the caller.

## Events

None today — this is a chrome primitive. When the
[plugin architecture](../07-roadmap/01-plugin-architecture.md) grows a shelf
slot, a contributed panel would be wrapped in this the same way, so it comes
and goes like the built-in ones.

## Lifecycle

Stateless. The animation lives in the `TweenAnimationBuilder`, which begins
whenever `visible` changes and ends on its own; there is no controller to
dispose. When the value reaches 0 the subtree is dropped entirely.

## Failure and recovery

- A reader who has asked for less motion gets the change at once, with no
  animation (`lib/api/widgets/collapsible_panel.dart:28`,
  `lib/api/widgets/collapsible_panel.dart:32`).
- Toggling mid-flight is safe: `TweenAnimationBuilder` retargets from wherever
  the value currently is, so a fast double-toggle reverses smoothly instead of
  jumping.
- The panel's contents keep their layout while leaving, which
  `test/presentation/reader_chrome_test.dart:90-101` guards by measuring the
  child's width partway through the animation.

## Transition

Both anticipated callers now exist: compact mode overlays the page and
[Panel Resize Handle](19-panel-resize-handle.md) lets a reader change the
`width` passed here. Neither changed this primitive: it still receives one
width and keeps the child at that width for the whole collapse animation.
