# Shell

## Purpose and boundary

The shell is the room around the document. `VisualMdApp` builds the Flutter
application; `ReaderScreen` arranges the top bar, shelf, reading pane, outline,
search surfaces, and transient feedback.

It presents controller state and reports reader intent. Platform-shaped needs
such as drop capture, window dragging, top-bar geometry, and external links
arrive as values or functions (`lib/api/app.dart`), so the widget tree
does not discover platform services for itself.

## Present wiring

`VisualMdApp` listens only to the controller's immutable appearance projection
and creates the light and dark `ThemeData` values. A `FollowSystem` choice uses
`ThemeMode.system`; a fixed choice uses the brightness of that theme. Library,
search, panel, and document notifications therefore stop at `ReaderScreen`
instead of reconstructing the `MaterialApp` above it. The app then wraps the
screen in the platform's drop region (`lib/api/app.dart`,
`lib/api/reader_controller.dart`).

`ReaderScreen` has three persistent areas:

1. The shelf presents standalone Markdown, folder roots, and unavailable
   workspace sources.
2. The centre presents the active document, or the empty-library state.
3. The outline presents the active document's headings.

Wide windows place those areas in a row. Below 1180 logical pixels, the page
keeps the full window and one side panel may overlay it at a time
(`lib/api/screens/reader_screen.dart`,
`lib/api/screens/reader_screen.dart`).

### Shortcuts and search

One autofocus shortcut scope provides Command bindings on macOS and Control
bindings elsewhere. It covers shelf and outline visibility, document and
library search, match navigation, text size, workspace actions, source Open,
and the sample library (`lib/api/screens/reader_screen.dart`). Native menu
commands reach the same controller methods and transient search, Appearance,
shortcut, and licence surfaces through the composition root
(`lib/api/reader_ui_command.dart`); see
[Workspace Actions](21-workspace-actions.md).

Current-document search places [Search](17-search.md)'s find bar over the page.
Library search temporarily replaces the shelf contents, while selecting a
result returns to the open document with that occurrence active
(`lib/api/screens/reader_screen.dart`,
`lib/api/screens/reader_screen.dart`).

### Panels and reading measure

Both side panels are wrapped in a
[Collapsible Panel](10-collapsible-panel.md). A wide panel returns its width to
the page as it leaves. A compact panel overlays the page and closes the panel
on the opposite side.

Wide shelf and outline visibility are independent, restored reader preferences.
Compact overlays deliberately do not change them: opening, selecting from, or
dismissing a compact panel lasts only for that transient interaction. A page
press, `Escape`, or Command-Period dismisses the open overlay; selecting a
document or outline heading does the same after completing the navigation
(`lib/api/reader_controller.dart`,
`lib/api/screens/reader_screen.dart`).

On wide windows, a [Panel Resize Handle](19-panel-resize-handle.md) sits at each
inner edge. The shell asks [Panel Widths](18-panel-widths.md) to fit both
preferences around the measured prose width plus its gutters, so side
furniture yields before the reading measure
(`lib/api/screens/reader_screen.dart`,
`lib/api/screens/reader_screen.dart`). Compact overlays keep the same
preferences but have no resize seam.

The shelf receives both the projected `Library` and durable workspace state.
That lets it keep unavailable sources in their saved positions with reconnect
and remove actions while ordinary folder and document rows remain domain
values (`lib/api/screens/reader_screen.dart`).

### Top bar and transient layers

`_TopBar` is one 52-point unified title bar. Its leading group contains the
shelf toggle and product identity, its centre reports the active document title
and file name, and its trailing group exposes document search, the theme picker,
and the outline toggle. The picker arrives as a complete widget, so the bar owns
its position without owning theme behavior
(`lib/api/screens/reader_screen.dart`). A custom multi-child layout measures the
unequal command clusters, reserves the larger width on both sides, and places
the document identity on the geometric centre of the complete window rather
than the leftover gap (`lib/api/screens/reader_screen.dart`). Both toggles use
[Pressable](09-pressable.md), carry separate Show/Hide shelf and outline names
for assistive technology, and remain disabled until a library exists.
Document-title and toggle-icon replacements cross-fade for 140 ms during
ordinary use. Reduce Motion makes both replacements immediate; it changes only
the automatic transition and leaves direct reader input untouched
(`lib/api/screens/reader_screen.dart`,
`test/presentation/reader_chrome_test.dart`).

On macOS the visible identity remains Flutter chrome, but the hidden AppKit
window title follows the current document for Mission Control and assistive
technology, falling back to **Visual MD** when no document is open. The same
small state projection keeps native reader actions enabled only when their
library or document exists and gives Shelf and Outline native checkmarks
(`lib/main.dart`, `lib/infrastructure/platform/native_reader_state.dart`,
`macos/Runner/MainFlutterWindow.swift`).

The permanent room uses [Library Chrome](28-library-chrome.md)'s three opaque
planes. Page, side panels, and the unified top bar separate mostly by surface
tone; only the permanent seams keep a softened divider. Menus and find surfaces
alone rise above that room with shadow. Their corners descend from the native
window silhouette through one shared radius hierarchy; the host keeps ownership
of the actual outer window clipping.

Three layers may sit above the room:

- a two-pixel progress line while an operation runs over an open library;
- a persistent [Error Notice](20-error-notice.md) when that operation fails;
- `DropOverlay` while a folder or Markdown file is over the window.

They are derived from controller state and mounted in the shell's final stack
(`lib/api/screens/reader_screen.dart`).

## Inputs and outputs

Inputs are controller state, `openExternal`, an optional mixed-source opener,
platform top-bar geometry, the drop/window wrappers, and an optional callback
that reveals the user-theme directory
(`lib/api/screens/reader_screen.dart`). Outputs are controller calls from
buttons and shortcuts, plus external URLs passed back to the platform.

`_followLink` switches over the controller's typed link target. Anchors scroll
the current pane by the generated anchor string, so `#setup-1` reaches the
second identically titled heading rather than searching by visible words.
Document links open the new document before scrolling to an
optional anchor; external links leave through `openExternal`
(`lib/api/screens/reader_screen.dart`).

`WelcomeView` presents Open, Open Workspace, and Open Sample Library as one
command surface. Every row carries an icon, supporting copy, and a real
platform-appropriate shortcut; the mixed-source description appears only
where the platform provides that capability
(`lib/api/widgets/welcome_view.dart`, `lib/api/widgets/welcome_view.dart`). Drop guidance and
inline errors remain below the commands. Once a library exists but contains no
readable document, `_EmptyLibrary` offers another folder instead
(`lib/api/screens/reader_screen.dart`,
`lib/api/screens/reader_screen.dart`).

The welcome composition centres itself inside the available height at normal
desktop sizes. Below its preferred height it scrolls instead of overflowing,
so deliberately compact windows remain usable
(`lib/api/widgets/welcome_view.dart`, `lib/api/widgets/welcome_view.dart`).
Its launch actions share one elevated surface and a restrained shadow. The
surface deliberately has no perimeter stroke: elevation already separates the
group from the page, so a border would add a second signal without adding
structure (`lib/api/widgets/welcome_view.dart`).

## Events

None today. The shell is where future UI slots would be presented: top-bar
actions, shelf content, a document footer, or a status strip. The proposed
[Plugin Architecture](../07-roadmap/01-plugin-architecture.md) treats those as
typed positions owned by the shell rather than as widgets that reach into it.

## Lifecycle

`ReaderScreen` lives for the session. It owns the active heading, compact-panel
flags, search query, result state, focus node, and debounce timer
(`lib/api/screens/reader_screen.dart`). The controller owns durable and
application state; changing workspace replaces what the shell presents rather
than replacing the shell itself.

## Failure and recovery

Opening and saving errors leave the current library visible and appear in
`ErrorNotice`; before a library exists, `WelcomeView` presents the same
controller error. Dismissal clears only that transient message. An unavailable
workspace source remains represented in the shelf until it is reconnected or
removed. Missing themes resolve to a built-in before the shell renders them.

Search requests carry a request number, so an older asynchronous result cannot
replace a newer query (`lib/api/screens/reader_screen.dart`). Closing
search cancels its debounce and removes highlights.

## Transition

Top-bar geometry already comes from `PlatformAdapters`, which lets macOS share
the row with native traffic-light controls. Matching custom chrome on Windows
would add native window controls and host verification while keeping the shell's
injected geometry contract unchanged.
