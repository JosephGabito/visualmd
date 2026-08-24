# Shell

## Purpose and boundary

The shell is the room around the document. `VisualMdApp` builds the Flutter
application; `ReaderScreen` arranges the top bar, shelf, reading pane, outline,
search surfaces, and transient feedback.

It presents controller state and reports reader intent. Platform-shaped needs
such as drop capture, window dragging, top-bar geometry, and external links
arrive as values or functions (`lib/api/app.dart:11-35`), so the widget tree
does not discover platform services for itself.

## Present wiring

`VisualMdApp` rebuilds from the controller and creates the light and dark
`ThemeData` values. A `FollowSystem` choice uses `ThemeMode.system`; a fixed
choice uses the brightness of that theme. It then wraps `ReaderScreen` in the
platform's drop region (`lib/api/app.dart:62-89`).

`ReaderScreen` has three persistent areas:

1. The shelf presents standalone Markdown, folder roots, and unavailable
   workspace sources.
2. The centre presents the active document, or the empty-library state.
3. The outline presents the active document's headings.

Wide windows place those areas in a row. Below 1180 logical pixels, the page
keeps the full window and one side panel may overlay it at a time
(`lib/api/screens/reader_screen.dart:193-220`,
`lib/api/screens/reader_screen.dart:595-616`).

### Shortcuts and search

One autofocus shortcut scope provides Command bindings on macOS and Control
bindings elsewhere. It covers shelf and outline visibility, document and
library search, match navigation, text size, workspace actions, source Open,
and the sample library (`lib/api/screens/reader_screen.dart:251-351`). Native File-menu commands reach
the same controller methods through the composition root; see
[Workspace Actions](21-workspace-actions.md).

Current-document search places [Search](17-search.md)'s find bar over the page.
Library search temporarily replaces the shelf contents, while selecting a
result returns to the open document with that occurrence active
(`lib/api/screens/reader_screen.dart:406-449`,
`lib/api/screens/reader_screen.dart:461-471`).

### Panels and reading measure

Both side panels are wrapped in a
[Collapsible Panel](10-collapsible-panel.md). A wide panel returns its width to
the page as it leaves. A compact panel overlays the page and closes the panel
on the opposite side.

On wide windows, a [Panel Resize Handle](19-panel-resize-handle.md) sits at each
inner edge. The shell asks [Panel Widths](18-panel-widths.md) to fit both
preferences around the measured prose width plus its gutters, so side
furniture yields before the reading measure
(`lib/api/screens/reader_screen.dart:367-404`,
`lib/api/screens/reader_screen.dart:451-556`). Compact overlays keep the same
preferences but have no resize seam.

The shelf receives both the projected `Library` and durable workspace state.
That lets it keep unavailable sources in their saved positions with reconnect
and remove actions while ordinary folder and document rows remain domain
values (`lib/api/screens/reader_screen.dart:472-490`).

### Top bar and transient layers

`_TopBar` contains the shelf toggle, product mark and name, theme picker, and
outline toggle. The picker arrives as a complete widget, so the bar owns its
position without owning theme behavior
(`lib/api/screens/reader_screen.dart:655-720`). Both toggles use
[Pressable](09-pressable.md) and remain disabled until a library exists.

Three layers may sit above the room:

- a two-pixel progress line while an operation runs over an open library;
- a persistent [Error Notice](20-error-notice.md) when that operation fails;
- `DropOverlay` while a folder or Markdown file is over the window.

They are derived from controller state and mounted in the shell's final stack
(`lib/api/screens/reader_screen.dart:558-647`).

## Inputs and outputs

Inputs are controller state, `openExternal`, an optional mixed-source opener,
platform top-bar geometry, the drop/window wrappers, and an optional callback
that reveals the user-theme directory
(`lib/api/screens/reader_screen.dart:28-47`). Outputs are controller calls from
buttons and shortcuts, plus external URLs passed back to the platform.

`_followLink` switches over the controller's typed link target. Anchors scroll
the current pane; document links open the new document before scrolling to an
optional anchor; external links leave through `openExternal`
(`lib/api/screens/reader_screen.dart:200-217`).

`WelcomeView` presents Open, Open Workspace, and Open Sample Library as one
command surface. Every row carries an icon, supporting copy, and a real
platform-appropriate shortcut; the mixed-source description appears only
where the platform provides that capability
(`lib/api/widgets/welcome_view.dart:68-104`, `:240-258`). Drop guidance and
inline errors remain below the commands. Once a library exists but contains no
readable document, `_EmptyLibrary` offers another folder instead
(`lib/api/screens/reader_screen.dart:583-594`,
`lib/api/screens/reader_screen.dart:765-797`).

The welcome composition centres itself inside the available height at normal
desktop sizes. Below its preferred height it scrolls instead of overflowing,
so deliberately compact windows remain usable
(`lib/api/widgets/welcome_view.dart:31-47`, `:144-156`).

## Events

None today. The shell is where future UI slots would be presented: top-bar
actions, shelf content, a document footer, or a status strip. The proposed
[Plugin Architecture](../07-roadmap/01-plugin-architecture.md) treats those as
typed positions owned by the shell rather than as widgets that reach into it.

## Lifecycle

`ReaderScreen` lives for the session. It owns the active heading, compact-panel
flags, search query, result state, focus node, and debounce timer
(`lib/api/screens/reader_screen.dart:53-77`). The controller owns durable and
application state; changing workspace replaces what the shell presents rather
than replacing the shell itself.

## Failure and recovery

Opening and saving errors leave the current library visible and appear in
`ErrorNotice`; before a library exists, `WelcomeView` presents the same
controller error. Dismissal clears only that transient message. An unavailable
workspace source remains represented in the shelf until it is reconnected or
removed. Missing themes resolve to a built-in before the shell renders them.

Search requests carry a request number, so an older asynchronous result cannot
replace a newer query (`lib/api/screens/reader_screen.dart:111-140`). Closing
search cancels its debounce and removes highlights.

## Transition

Top-bar geometry already comes from `PlatformAdapters`, which lets macOS share
the row with native traffic-light controls. Matching custom chrome on Windows
would add native window controls and host verification while keeping the shell's
injected geometry contract unchanged.
