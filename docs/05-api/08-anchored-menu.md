# Anchored Menu

## Purpose and boundary

`AnchoredMenu` is a menu that opens from the thing you clicked. It owns the
overlay, the dismissal rules and the motion; it owns none of the content —
callers pass a trigger and a list of rows. It replaces Flutter's
`PopupMenuButton` so the surface can remain visually attached to its trigger
and use the same restrained motion as the rest of the reading shell.

It is a widget in the API ring. It knows nothing about themes, libraries or
documents: [ThemePicker](07-theme-picker.md) is its first caller, and the UI
slots described in [the plugin architecture](../07-roadmap/01-plugin-architecture.md)
are the next.

## Present wiring

The trigger is wrapped in a `CompositedTransformTarget` and an `OverlayPortal`
(`lib/api/widgets/anchored_menu.dart:115-129`), with the controller and portal
held by its state (`lib/api/widgets/anchored_menu.dart:59-65`). Opening shows
the portal and drives one `AnimationController` forward; closing reverses it,
and a status listener hides the portal only once the surface has gone
(`lib/api/widgets/anchored_menu.dart:67-97`).

The surface hangs off the trigger with `CompositedTransformFollower`, its
top-right corner pinned to the trigger's bottom-right
(`lib/api/widgets/anchored_menu.dart:184-195`).

### It opens on the press

The trigger is a [Pressable](09-pressable.md)
(`lib/api/widgets/anchored_menu.dart:101-108`), the same press behaviour the
shelf and outline toggles use: it listens for raw pointer events rather than
taps, so it neither waits for the button to come back up nor can be deferred by
the gesture arena — which matters under the window-drag handler that wraps the
top bar on macOS (see
[Window Chrome](../03-infrastructure/desktop/03-window-chrome.md)). Sharing it
also means the menu's trigger leans in and gives under the press exactly as
every other control in the bar does.

What it does *not* do is press-drag-release, the way a native menu bar lets you
hold, slide down and let go on a row. Once a pointer is down, Flutter routes
the rest of that pointer's events to the targets hit at the press, so a row
never sees the release. Supporting it would mean hit-testing the menu by hand
from the trigger; it is not worth that today.

### The motion, and why

| Principle | Here | Where |
|---|---|---|
| Staging — spatial continuity | The surface scales from its top-right corner, the corner it hangs from, so it reads as coming *from* the button rather than appearing beside it | `lib/api/widgets/anchored_menu.dart:200-201` |
| Slow in, slow out | `Easing.emphasizedDecelerate` entering, `Easing.emphasizedAccelerate` leaving — Material 3's asymmetric pair | `lib/api/widgets/anchored_menu.dart:156-160` |
| Never from zero | Scale runs 0.94 → 1, not 0 → 1: a surface that starts at nothing reads as inflating | `lib/api/widgets/anchored_menu.dart:200` |
| Follow-through | Rows arrive after the surface and after each other, each fading up 8 px | `lib/api/widgets/anchored_menu.dart:271-285` |
| Timing | 220 ms in, 140 ms out — dismissal is quicker than arrival, and both stay under a third of a second | `lib/api/widgets/anchored_menu.dart:55-56` |
| Anticipation | The trigger grows to 1.06 under the pointer and gives to 0.94 under a press — shared with every other control | `lib/api/widgets/pressable.dart:34-35` |

Opacity finishes early — over the first 55 % of the entrance
(`lib/api/widgets/anchored_menu.dart:151-155`) — so the menu is fully visible
while it is still settling, which reads faster than it is.

The cascade is spent by 70 % of the entrance however many rows there are
(`lib/api/widgets/anchored_menu.dart:271-274`), so a long theme list never
feels slower than a short one. On the way out the rows leave together with the
surface rather than in sequence (`lib/api/widgets/anchored_menu.dart:278`).

Nothing overshoots or bounces; the movement identifies the menu's origin
without asking for attention of its own.

## Inputs and outputs

| In | Type | Meaning |
|---|---|---|
| `trigger` | `Widget Function(BuildContext, bool isOpen)` | The button; told whether the menu is open so it can respond |
| `items` | `List<Widget> Function(BuildContext, VoidCallback close)` | The rows, in order; `close` dismisses |
| `width` | `double` | Surface width, default 260 |
| `tooltip` | `String?` | Optional tooltip on the trigger |

Out: nothing. Rows report to their own callers; the menu only opens and closes.

## Events

None today. When UI slots land, a slot's contributors become the `items` list
and the menu stays exactly as it is — that is the point of keeping content out
of it.

## Lifecycle

One `AnimationController` lives as long as the widget
(`lib/api/widgets/anchored_menu.dart:60`, disposed at `:75-79`). The overlay
child exists only between `show()` and the reverse completing, so a closed menu
costs nothing but the trigger.

## Failure and recovery

- Pressing the trigger while the menu is open closes it: the dismissal layer
  covers the trigger, so the press lands there
  (`lib/api/widgets/anchored_menu.dart:170-173`).
- `Escape` dismisses (`lib/api/widgets/anchored_menu.dart:186`), as does a
  press anywhere outside (`lib/api/widgets/anchored_menu.dart:170-173`).
- The available height comes from layout, not from `MediaQuery`
  (`lib/api/widgets/anchored_menu.dart:162-167`): an `OverlayPortal`'s child
  inherits from the trigger's place in the tree. Using `MediaQuery` there can
  produce a zero-height hit-test area even while the menu paints correctly.
  `test/presentation/theme_picker_test.dart:62-72` checks every row with a real
  pointer so this remains visible.
- A reader who has asked for less motion gets the menu at once, with no
  transforms (`lib/api/widgets/anchored_menu.dart:97-99`, `:269`).

## Transition

The surface is deliberately plain so a slot can fill it. Two things are likely
next: keyboard navigation through the rows, and a second anchor position for
menus opened from the left of the window, where a top-*left* origin is the
honest one.
