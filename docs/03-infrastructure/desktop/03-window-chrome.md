# Window Chrome

## Purpose and boundary

On macOS the app shows one title bar, not two: the system title bar is made
invisible, the reading room extends underneath it, and the traffic lights sit
inline with the app's own top bar. The split of responsibility is the point
of this document:

| Who | Knows | Does not know |
|-----|-------|---------------|
| `MainFlutterWindow.swift` | AppKit window styling | anything about Flutter layout |
| `platform_io.dart` | how tall the title-bar zone is, how far right the lights reach, how to drag a window | what the bar contains |
| the API's top bar | a height, a left inset, a wrapper to apply | what a traffic light is |

## Present wiring

**Native.** `MainFlutterWindow.awakeFromNib` sets the window up before the
first frame (`macos/Runner/MainFlutterWindow.swift:22-43`):

| Setting | Effect | Evidence |
|---------|--------|----------|
| `titleVisibility = .hidden` | no title text | `macos/Runner/MainFlutterWindow.swift:31` |
| `titlebarAppearsTransparent = true` | no title-bar background | `:32` |
| `styleMask.insert(.fullSizeContentView)` | Flutter's view extends under the title-bar zone | `:33` |
| `titlebarSeparatorStyle = .none` | no hairline between zone and content | `:34` |
| `toolbarStyle = .unified` + an empty `NSToolbar` | the zone grows to toolbar height and macOS centres the traffic lights in it | `:37-40` |
| `minSize = 720 × 480` | preserves a usable three-pane layout | `:41` |

The empty toolbar is the trick: it has no items and draws nothing, but its
presence makes the invisible zone tall enough (measured at startup; 52 px if the window reports nothing) for the lights to sit
centred rather than hugging the top edge.

**Platform adapter.** On macOS only, `createPlatformAdapters` awaits
`windowManager.ensureInitialized()` and `getTitleBarHeight()`, then answers
`topBar = (height: <measured, or 52 if 0>, leadingInset: 84)`
(`lib/infrastructure/platform/platform_io.dart:26-35`). 84 px is just past
the green light. Every other platform answers `plainTopBar`
(`lib/infrastructure/platform/platform_adapters.dart:58-62`,
`lib/infrastructure/platform/platform_io.dart:27-28`).

`windowDragRegion` restores what a transparent title bar loses: on macOS it
wraps the bar in `window_manager`'s `DragToMoveArea` (a native `performDrag`)
inside a `GestureDetector` whose double-tap toggles `maximize`/`unmaximize`,
matching the native title-bar gesture; elsewhere it returns the child
untouched because the system title bar is still there
(`lib/infrastructure/platform/platform_io.dart:99-109`).

**API.** `VisualMdApp` receives `topBar` and `windowDragRegion` from `main.dart`
(`lib/main.dart:247-255`) and passes them to `ReaderScreen`, which sizes and
insets the bar and applies the wrapper
(`lib/api/screens/reader_screen.dart:511-514`). Platform checks stay out of the
UI. See [Shell](../../05-api/02-shell.md).

## Inputs and outputs

| Direction | What | Evidence |
|-----------|------|----------|
| in (macOS) | title-bar height from the window | `lib/infrastructure/platform/platform_io.dart:32-34` |
| out | `({double height, double leadingInset}) topBar` | `lib/infrastructure/platform/platform_adapters.dart:36-38` |
| out | `Widget windowDragRegion(Widget)` | `lib/infrastructure/platform/platform_adapters.dart:40-42` |

## Events

None. Window chrome contributes layout and interaction, not domain activity.

## Lifecycle

Native settings are applied once when the window wakes. The adapter measures
once at startup; the bar does not re-measure if the system changes title-bar
metrics mid-session.

## Failure and recovery

- A 0 from `getTitleBarHeight` (plugin not ready, unusual window) falls back
  to 52 so the inset still clears the lights
  (`lib/infrastructure/platform/platform_io.dart:33-34`).
- If `window_manager` ever failed to initialise, `createPlatformAdapters`
  would throw before `runApp`; there is no degraded mode today.
- Verified by screenshot on macOS 26 on 2026-08-22: lights centred, no overlap.
  Drag and double-click zoom are not yet confirmed by hand.

## Transition

- Windows and Linux keep the system title bar. Custom chrome there would also
  need accessible minimise, maximise, and close controls before the native bar
  could be hidden safely.
- The 84 px inset is a constant; if the traffic-light geometry changes in a
  future macOS it is one number in `platform_io.dart`.
