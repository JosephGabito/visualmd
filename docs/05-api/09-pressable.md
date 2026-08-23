# Pressable

## Purpose and boundary

`Pressable` is the press behaviour every control in the chrome shares: it acts
the moment the pointer goes down, and it answers before it acts. It owns the
hover and press feedback and nothing else — no painting, no icon, no label. The
caller supplies the child and the callback.

It is a widget in the API ring. It knows nothing about themes, libraries or
platforms; the [Anchored Menu](08-anchored-menu.md) trigger and the top bar's
shelf and outline buttons are its callers.

## Present wiring

The control is a raw `Listener`, not a `GestureDetector`
(`lib/api/widgets/pressable.dart:49-56`). That is the whole point:

- **It does not wait for the release.** `onPointerDown` fires the callback
  immediately (`lib/api/widgets/pressable.dart:51-55`). A control that acts on
  the way back up puts the interface a beat behind the hand.
- **It cannot be deferred.** Pointer events are not subject to the gesture
  arena, so nothing upstream can hold the callback back while it decides
  whether it wanted the gesture. That matters here because the macOS top bar is
  wrapped in a window-drag handler (see
  [Window Chrome](../03-infrastructure/desktop/03-window-chrome.md)); a tap
  recognizer competing with a pan recognizer can have its callback delayed
  until the arena resolves.

Around that sits the anticipation. The control scales to 1.06 while the pointer
is over it or while it is `active`, and gives to 0.94 while pressed
(`lib/api/widgets/pressable.dart:34-35`, `lib/api/widgets/pressable.dart:59-64`),
over 120 ms of `Curves.easeOut` (`lib/api/widgets/pressable.dart:65-66`). Hover
is tracked by a `MouseRegion`, which also carries the cursor
(`lib/api/widgets/pressable.dart:45-48`).

A reader who has asked for less motion gets the state changes with no
animation at all (`lib/api/widgets/pressable.dart:43`,
`lib/api/widgets/pressable.dart:65`).

## Inputs and outputs

| In | Type | Meaning |
|---|---|---|
| `onPress` | `VoidCallback?` | Called on pointer down. `null` disables the control |
| `active` | `bool` | Holds it raised while what it opened is still on screen |
| `tooltip` | `String?` | Wraps the control in a `Tooltip` when given (`lib/api/widgets/pressable.dart:72-74`) |
| `child` | `Widget` | What is drawn |

Out: `onPress()`, once per press. Nothing else.

## Events

None today — this is a chrome primitive, not a domain participant. When the
[plugin architecture](../07-roadmap/01-plugin-architecture.md) grows UI slots,
a slot's controls are what get built from this, so their press behaviour
matches the rest of the bar without each contributor re-deciding it.

## Lifecycle

One `State` per control, alive as long as the control is on screen. It keeps
two flags — hovered and pressed (`lib/api/widgets/pressable.dart:37-38`) — and
nothing else; there is no controller or subscription to dispose.

## Failure and recovery

- A `null` `onPress` disables the control rather than hiding it: the pointer
  callback is not installed, the cursor stays plain, the scale stays at 1, and
  the child dims to 40 % (`lib/api/widgets/pressable.dart:42`,
  `lib/api/widgets/pressable.dart:46`, `lib/api/widgets/pressable.dart:60-61`,
  `lib/api/widgets/pressable.dart:67`). The top bar uses this before a library
  is open.
- A press that ends elsewhere, or is cancelled by the system, still releases
  the pressed state (`lib/api/widgets/pressable.dart:57-58`), so a control
  cannot be left stuck looking pressed.
- Acting on the way down means there is no "slide off to cancel". That is the
  trade: for toggles and menus the immediacy is worth more than the escape
  hatch, and both callers are cheap to undo.

## Transition

Two things are likely next: a keyboard path, so the same controls can be
reached without a pointer, and a focus ring drawn from the palette. Both belong
here rather than in each caller, which is the reason this exists as a widget
instead of a copied `Listener`.
