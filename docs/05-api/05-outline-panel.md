# Outline Panel

## Purpose and boundary

`OutlinePanel` lists the open document's headings and reports which one the
reader tapped (`lib/api/widgets/outline_panel.dart`). It consumes the
domain's `TableOfContents` and `Heading` values unchanged. Anchors, levels,
and text were all fixed by the
[document outline](../01-domain/03-document-outline.md) parser.

## Present wiring

Mounted in the shell's right column at a remembered width, only while
`outlineVisible` is on and the table of contents is non-empty
(`lib/api/screens/reader_screen.dart`,
`lib/api/screens/reader_screen.dart`). Its resize seam sits on the
left edge. `activeAnchor` comes from the shell's dedicated `ValueNotifier`, so
crossing a heading while scrolling rebuilds the outline without rebuilding the
reading pane, shelf, or window chrome. `onSelect` scrolls the pane to the heading's
anchor; selecting inside a compact overlay also closes it
(`lib/api/screens/reader_screen.dart`).

The build (`lib/api/widgets/outline_panel.dart`):

1. `PanelHeading('On this page')` (`lib/api/widgets/outline_panel.dart`).
2. A lazy `ListView.builder` of `_OutlineEntry` rows, one per heading, with `depth`
   equal to `heading.level - tableOfContents.baseLevel`
   (`lib/api/widgets/outline_panel.dart`,
   `lib/api/widgets/outline_panel.dart`), so a document that starts at
   `##` still reads flush left.
3. An empty-state line, "No headings in this document."
   (`lib/api/widgets/outline_panel.dart`) — reachable only if the
   shell's non-empty guard is removed.

`_OutlineEntry` (`lib/api/widgets/outline_panel.dart`) indents 14 px
per depth, uses the shared 32 px `ChromeListRow`, paints an accessible selected
ground and a short 2 px location mark when active, shows
`(untitled)` for a blank heading (`lib/api/widgets/outline_panel.dart`),
and styles top-level and active entries in ink, deeper inactive ones in muted,
with the active entry semibold (`lib/api/widgets/outline_panel.dart`).
Text, ground, and the location mark ensure colour is not the only active cue.

## Inputs and outputs

In: `tableOfContents`, `activeAnchor`, `onSelect`
(`lib/api/widgets/outline_panel.dart`). Out: `onSelect(heading)` on
tap (`lib/api/widgets/outline_panel.dart`).

## Events

None today. Under the plugin architecture this panel is a natural home for
a second **shelf panel**-style slot on the right: document metadata from
front matter, word counts, or backlinks, stacked under the outline.

## Lifecycle

Stateless. A new document rebuilds it with a new table of contents. Active
heading changes rebuild only its mounted viewport rows; a 10,000-heading
outline does not construct the other 9,000-plus rows
(`test/presentation/outline_panel_test.dart`,
`test/presentation/reader_chrome_test.dart`).

## Failure and recovery

Nothing to fail. Anchors are unique within a document by construction
(`lib/domain/reading/document_outline.dart`), so `active` matches at most one
entry.

## Transition

Long outlines will want the active entry kept in view; the panel would need
its own `ScrollController` and a per-entry key, mirroring the reading pane.
