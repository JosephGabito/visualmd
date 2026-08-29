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
first frame (`macos/Runner/MainFlutterWindow.swift`):

| Setting | Effect | Evidence |
|---------|--------|----------|
| `titleVisibility = .hidden` | no title text | `macos/Runner/MainFlutterWindow.swift` |
| `titlebarAppearsTransparent = true` | no title-bar background | `macos/Runner/MainFlutterWindow.swift` |
| `styleMask.insert(.fullSizeContentView)` | Flutter's view extends under the title-bar zone | `macos/Runner/MainFlutterWindow.swift` |
| `titlebarSeparatorStyle = .none` | no hairline between zone and content | `macos/Runner/MainFlutterWindow.swift` |
| `toolbarStyle = .unified` + an empty `NSToolbar` | the zone grows to toolbar height and macOS centres the traffic lights in it | `macos/Runner/MainFlutterWindow.swift` |
| fullscreen notifications | hide that empty toolbar while no persistent traffic lights need it | `macos/Runner/MainFlutterWindow.swift` |
| `minSize = 720 × 480` | preserves a usable three-pane layout | `macos/Runner/MainFlutterWindow.swift` |
| `setFrameAutosaveName("visualmd.main-window")` | lets AppKit save moves and resizes, then restore the last frame on the next launch | `macos/Runner/MainFlutterWindow.swift` |
| hidden native title | names the window after the current document for Mission Control and accessibility, or **Visual MD** when empty | `macos/Runner/MainFlutterWindow.swift` |

The empty toolbar is the trick: it has no items and draws nothing, but its
presence makes the invisible zone tall enough (measured at startup; 52 px if
the window reports nothing) for the lights to sit centred rather than hugging
the top edge. It is hidden before entering fullscreen and restored before exit;
otherwise AppKit carries its empty region into fullscreen and covers the
Flutter top bar (`macos/Runner/MainFlutterWindow.swift`).

**Platform adapter.** On macOS only, `createPlatformAdapters` awaits
`windowManager.ensureInitialized()` and `getTitleBarHeight()`, then answers
`topBar = (height: <measured, or 52 if 0>, leadingInset: 84)`
(`lib/infrastructure/platform/platform_io.dart`). 84 px is just past
the green light. Every other platform answers `plainTopBar`
(`lib/infrastructure/platform/platform_adapters.dart`,
`lib/infrastructure/platform/platform_io.dart`).

`windowDragRegion` restores what a transparent title bar loses: on macOS it
wraps the bar in `window_manager`'s `DragToMoveArea` (a native `performDrag`)
inside a `GestureDetector` whose double-tap toggles `maximize`/`unmaximize`,
matching the native title-bar gesture; elsewhere it returns the child
untouched because the system title bar is still there
(`lib/infrastructure/platform/platform_io.dart`).

The native title is state, not visible layout. The composition root listens to
the controller and sends `NativeReaderState` through the platform adapter after
the first frame and after later reader changes. Desktop forwards it to AppKit
on macOS; other desktop systems and the web deliberately do nothing
(`lib/main.dart`, `lib/infrastructure/platform/native_reader_state.dart`,
`lib/infrastructure/io/desktop_commands.dart`,
`lib/infrastructure/platform/platform_io.dart`).

Windows keeps its native caption and therefore its genuine minimize, maximize,
close, resize, Snap Layout, keyboard, and accessibility behavior. A second
host projection sends the active Flutter top-bar and ink colours whenever the
Material theme changes. The Win32 runner applies those values through
`DWMWA_CAPTION_COLOR` and `DWMWA_TEXT_COLOR`, available from Windows 11 build
22000, so the caption blends with the reading room without replacing native
controls (`lib/api/app.dart`, `lib/infrastructure/io/desktop_commands.dart`,
`windows/runner/flutter_window.cpp`).

**API.** `VisualMdApp` receives `topBar` and `windowDragRegion` from `main.dart`
(`lib/main.dart`) and passes them to `ReaderScreen`, which sizes and
insets the bar and applies the wrapper
(`lib/api/screens/reader_screen.dart`). Platform checks stay out of the
UI. See [Shell](../../05-api/02-shell.md).

## Inputs and outputs

| Direction | What | Evidence |
|-----------|------|----------|
| in (macOS) | title-bar height from the window | `lib/infrastructure/platform/platform_io.dart` |
| out | `({double height, double leadingInset}) topBar` | `lib/infrastructure/platform/platform_adapters.dart` |
| out | `Widget windowDragRegion(Widget)` | `lib/infrastructure/platform/platform_adapters.dart` |
| in | `NativeReaderState.documentTitle` | hidden AppKit window title (`macos/Runner/MainFlutterWindow.swift`) |
| out (Windows) | active top-bar and ink ARGB values | native DWM caption (`lib/api/app.dart`, `windows/runner/flutter_window.cpp`) |

## Events

Controller notifications project the current document title into AppKit. This
is host-state synchronization, not domain activity.
Material theme changes separately project the current caption colours to
Windows; they are presentation synchronization, not domain activity.

## Lifecycle

Native settings, the state receiver, frame autosave, and fullscreen observers
are installed when the window wakes. AppKit restores the named frame when one
exists and otherwise leaves the 1280 × 800 frame from `MainMenu.xib` in place.
It then saves later moves and resizes under that same name. The initial reader
state arrives after Flutter's first frame; subsequent controller changes keep
the hidden title current. The adapter measures geometry once at startup; the
bar does not re-measure if the system changes title-bar metrics mid-session.
The observers leave with the window (`macos/Runner/MainFlutterWindow.swift`,
`macos/Runner/Base.lproj/MainMenu.xib`).

## Failure and recovery

- A 0 from `getTitleBarHeight` (plugin not ready, unusual window) falls back
  to 52 so the inset still clears the lights
  (`lib/infrastructure/platform/platform_io.dart`).
- If `window_manager` ever failed to initialise, `createPlatformAdapters`
  would throw before `runApp`; there is no degraded mode today.
- A missing saved frame is the normal first-launch case: AppKit keeps the
  1280 × 800 nib frame rather than inventing a second fallback.
- Verified by screenshot on macOS 26 on 2026-08-22: lights centred, no overlap.
  Drag and double-click zoom are not yet confirmed by hand.
- Fullscreen toolbar visibility is guarded by a source-level platform test and
  was verified visually on macOS 26 on 2026-08-24: the Flutter top bar reaches
  the top edge, with no empty native strip.

## Transition

- Windows and Linux keep the system title bar. Windows 11 tints its caption;
  hiding it entirely would still require accessible minimise, maximise, and
  close controls plus native Snap behavior before it could be done safely.
- The 84 px inset is a constant; if the traffic-light geometry changes in a
  future macOS it is one number in `platform_io.dart`.
