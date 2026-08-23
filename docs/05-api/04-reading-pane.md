# Reading Pane

## Purpose and boundary

`ReadingPane` is the page: one document, set by
[Document View](12-document-view.md) and watched so the outline knows where
the reader is (`lib/api/widgets/reading_pane.dart:11-27`). It owns the scroll,
the page furniture — a breadcrumb, and a stand-in title for a document that
never names itself — and the tracking that decides which heading is being
read. It parses nothing and styles nothing.

## Present wiring

The shell mounts it under a `GlobalKey<ReadingPaneState>` with the reader's
current scale, `onLink` and `onActiveHeadingChanged` bound
(`lib/api/screens/reader_screen.dart:299-314`).

The build (`lib/api/widgets/reading_pane.dart:128-203`):

- A `Scrollbar` over a `SingleChildScrollView`, padded 48 px at the sides on
  ordinary windows and 24 px below 600 px, then
  in lines vertically — one and a half above, six below, so the last paragraph
  is never pinned to the bottom edge
  (`lib/api/widgets/reading_pane.dart:133-135`,
  `lib/api/widgets/reading_pane.dart:143-154`).
- A `SelectionArea` around everything, so text selects across the whole
  document (`lib/api/widgets/reading_pane.dart:154`).
- A `ReadingTheme` built once per frame from the palette, the faces and the
  scale (`lib/api/widgets/reading_pane.dart:132`). See
  [Reading Theme](14-reading-theme.md).
- The breadcrumb and any stand-in title inside a `SizedBox` of
  `theme.proseWidth`, because everything on the page should hang off one left
  edge rather than centring on the window
  (`lib/api/widgets/reading_pane.dart:155-186`).
- A stand-in H1 with `document.title` when the document has no level-1 heading
  of its own, so the page is never headless
  (`lib/api/widgets/reading_pane.dart:136-141`,
  `lib/api/widgets/reading_pane.dart:180-183`).
- One `DocumentView` for the whole document
  (`lib/api/widgets/reading_pane.dart:187-195`).

### One document, not a stack of sections

The page used to be cut into one widget per heading so that scroll targets
existed. It is not any more: the renderer registers a `GlobalKey` per
heading anchor as it builds
(`lib/api/render/document_view.dart:221-236`), and the pane owns that map
(`lib/api/widgets/reading_pane.dart:40-44`). Nothing is re-parsed per section, and
reference-style links no longer need duplicating across sections. See
[ADR 0004](../08-decisions/0004-sections-as-navigation-unit.md), which this
partly supersedes.

## Inputs and outputs

In: `reading` (document, outline and content), `scale`, `onLink`,
`onActiveHeadingChanged` (`lib/api/widgets/reading_pane.dart:13-29`).

Out:

- `onLink(href)` — passed to `DocumentView`, raised by the
  [Inline Composer](13-inline-composer.md) when a link is tapped
  (`lib/api/widgets/reading_pane.dart:187-195`).
- `onActiveHeadingChanged(heading)` whenever the heading nearest the top
  changes (`lib/api/widgets/reading_pane.dart:122-125`).
- `scrollToAnchor(anchor)`, called by the shell: `Scrollable.ensureVisible` on
  that heading's context, 320 ms, `easeOutCubic`, aligned to the top
  (`lib/api/widgets/reading_pane.dart:80-89`).

Active-heading tracking walks the outline's headings in order, measuring each
keyed heading's top against the page's top; the last one at or above the
120 px line wins (`lib/api/widgets/reading_pane.dart:35-38`,
`lib/api/widgets/reading_pane.dart:102-125`), falling back to the first heading.

## Events

None today. The **reading-pane block** slot belongs one level down, in
[Document View](12-document-view.md), where a contributor would render a fenced
language ([Plugin architecture](../07-roadmap/01-plugin-architecture.md)).

## Lifecycle

`initState` listens to the scroll controller and runs one tracking pass after
the first frame (`lib/api/widgets/reading_pane.dart:46-51`). When a different
document arrives the anchor keys are cleared, the active anchor is reset, and
after the frame the scroll jumps to the top and tracking runs again
(`lib/api/widgets/reading_pane.dart:53-71`). The controller is disposed with
the state (`lib/api/widgets/reading_pane.dart:74-78`).

Changing the text size rebuilds with a new scale; the column follows, because
it is derived rather than stored
(`test/presentation/text_size_test.dart:97-125`).

## Failure and recovery

`scrollToAnchor` does nothing for an unknown anchor
(`lib/api/widgets/reading_pane.dart:80-82`); tracking skips headings with no
render box yet (`lib/api/widgets/reading_pane.dart:107-111`) and reports nothing
for a document with no headings at all
(`lib/api/widgets/reading_pane.dart:119-121`). Relative images do not resolve
today; see the [backlog](../07-roadmap/02-backlog.md).

## Transition

Everything still builds at once inside one scroll view, which keeps
`ensureVisible` exact and remains the first thing to revisit for very long
documents. A lazy list would need anchor positions estimated ahead of layout.
