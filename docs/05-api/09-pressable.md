# Pressable

## Purpose and boundary

`Pressable` is the interaction contract every control in the chrome shares: it
acts the moment the pointer goes down, activates from Enter or Space, and gives
assistive technology one named button. It owns hover, press and focus feedback
but not the control's icon or visible label. The caller supplies the child,
accessible name and callback.

It is a widget in the API ring. It reads [Library Chrome](28-library-chrome.md)
but knows nothing about libraries or platforms; the [Anchored Menu](08-anchored-menu.md) trigger and the top bar's
shelf and outline buttons are its callers.

## Present wiring

The control is a raw `Listener`, not a `GestureDetector`
(`lib/api/widgets/pressable.dart`). That is the whole point:

- **It does not wait for the release.** `onPointerDown` fires the callback
  immediately (`lib/api/widgets/pressable.dart`). A control that acts on
  the way back up puts the interface a beat behind the hand.
- **It cannot be deferred.** Pointer events are not subject to the gesture
  arena, so nothing upstream can hold the callback back while it decides
  whether it wanted the gesture. That matters here because the macOS top bar is
  wrapped in a window-drag handler (see
  [Window Chrome](../03-infrastructure/desktop/03-window-chrome.md)); a tap
  recognizer competing with a pan recognizer can have its callback delayed
  until the arena resolves.

Around that sits the response. Hover, active, and press move through the shared
opaque chrome surfaces over 120 ms of `Curves.easeOut`; icon geometry remains
still, so a compact toolbar never twitches under the pointer
(`lib/api/widgets/pressable.dart`). Hover is tracked by a `MouseRegion`, which
also carries the cursor.

A reader who has asked for less motion gets the state changes with no
animation at all (`lib/api/widgets/pressable.dart`,
`lib/api/widgets/pressable.dart`).

The same callback is exposed through a semantic tap action and through
`ActivateIntent` for Enter and Space (`lib/api/widgets/pressable.dart`). A
transparent two-pixel border reserves room for the focus ring, so keyboard
focus becomes visible without shifting the bar. The caller's explicit
`semanticLabel` replaces the icon and tooltip in the accessibility tree; the
tooltip remains visual help rather than a second competing name
(`lib/api/widgets/pressable.dart`).

## Inputs and outputs

| In | Type | Meaning |
|---|---|---|
| `onPress` | `VoidCallback?` | Called on pointer down. `null` disables the control |
| `semanticLabel` | `String` | Stable accessible name, independent of icon and tooltip |
| `active` | `bool` | Holds it raised while what it opened is still on screen |
| `expanded` | `bool?` | Exposes whether a controlled surface is open |
| `focusNode` | `FocusNode?` | Optional caller-owned node for focus restoration |
| `tooltip` | `String?` | Wraps the control in a `Tooltip` when given (`lib/api/widgets/pressable.dart`) |
| `child` | `Widget` | What is drawn |

Out: `onPress()`, once per pointer press or keyboard activation. Nothing else.

## Events

None today — this is a chrome primitive, not a domain participant. When the
[plugin architecture](../07-roadmap/01-plugin-architecture.md) grows UI slots,
a slot's controls are what get built from this, so their press behaviour
matches the rest of the bar without each contributor re-deciding it.

## Lifecycle

One `State` per control, alive as long as the control is on screen. It keeps
hovered, pressed and focused flags (`lib/api/widgets/pressable.dart`). A focus
node supplied by the caller remains caller-owned; `Pressable` never disposes
it.

## Failure and recovery

- A `null` `onPress` disables the control rather than hiding it: pointer and
  keyboard activation are disabled, the semantic node reports that state, the
  cursor stays plain, the surface stays clear, and the child dims to 38 %
  (`lib/api/widgets/pressable.dart`,
  `lib/api/widgets/pressable.dart`, `lib/api/widgets/pressable.dart`,
  `lib/api/widgets/pressable.dart`). The top bar uses this before a library
  is open.
- A press that ends elsewhere, or is cancelled by the system, still releases
  the pressed state (`lib/api/widgets/pressable.dart`), so a control
  cannot be left stuck looking pressed.
- Acting on the way down means there is no "slide off to cancel". That is the
  trade: for toggles and menus the immediacy is worth more than the escape
  hatch, and both callers are cheap to undo.

## Transition

Future chrome controls should reuse this contract rather than recreating
pointer, keyboard, focus and semantic behavior at each call site. A different
interaction primitive belongs here only when a new control cannot honestly be
described as a button.
