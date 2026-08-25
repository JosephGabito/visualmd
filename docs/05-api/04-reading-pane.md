# Reading Pane

## Purpose and boundary

`ReadingPane` is the page: one document, set by
[Document View](12-document-view.md) and watched so the outline knows where
the reader is (`lib/api/widgets/reading_pane.dart`). It owns the scroll,
the page furniture — a breadcrumb, and a stand-in title for a document that
never names itself — and the tracking that decides which heading is being
read. It parses nothing and styles nothing.

## Present wiring

The shell mounts it under a `GlobalKey<ReadingPaneState>` with the reader's
current scale, `onLink` and `onActiveHeadingChanged` bound
(`lib/api/screens/reader_screen.dart`).

The build (`lib/api/widgets/reading_pane.dart`):

- A `Scrollbar` over a `SingleChildScrollView`, padded 48 px at the sides on
  ordinary windows and 24 px below 600 px, then
  in lines vertically — one and a half above, six below, so the last paragraph
  is never pinned to the bottom edge
  (`lib/api/widgets/reading_pane.dart`,
  `lib/api/widgets/reading_pane.dart`).
- A `SelectionArea` around everything, so text selects across the whole
  document (`lib/api/widgets/reading_pane.dart`).
- A `ReadingTheme` built once per frame from the palette, the faces and the
  scale (`lib/api/widgets/reading_pane.dart`). See
  [Reading Theme](14-reading-theme.md).
- The breadcrumb and any stand-in title inside a `SizedBox` of
  `theme.proseWidth`, because everything on the page should hang off one left
  edge rather than centring on the window
  (`lib/api/widgets/reading_pane.dart`).
- A stand-in H1 with `document.title` when the document has no level-1 heading
  of its own, so the page is never headless
  (`lib/api/widgets/reading_pane.dart`,
  `lib/api/widgets/reading_pane.dart`).
- One `DocumentView` for the whole document
  (`lib/api/widgets/reading_pane.dart`).

### One document, not a stack of sections

The page used to be cut into one widget per heading so that scroll targets
existed. It is not any more: the renderer registers a `GlobalKey` per
heading anchor as it builds
(`lib/api/render/document_view.dart`), and the pane owns that map
(`lib/api/widgets/reading_pane.dart`). Nothing is re-parsed per section, and
reference-style links no longer need duplicating across sections. See
[ADR 0004](../08-decisions/0004-sections-as-navigation-unit.md), which this
partly supersedes.

## Inputs and outputs

In: `reading` (document, outline and content), `imageLoader`, `scale`, `onLink`,
`onActiveHeadingChanged` (`lib/api/widgets/reading_pane.dart`).

Out:

- `onLink(href)` — passed to `DocumentView`, raised by the
  [Inline Composer](13-inline-composer.md) when a link is tapped
  (`lib/api/widgets/reading_pane.dart`).
- `onActiveHeadingChanged(heading)` whenever the heading nearest the top
  changes (`lib/api/widgets/reading_pane.dart`).
- `scrollToAnchor(anchor)`, called by the shell: `Scrollable.ensureVisible` on
  that heading's context, 320 ms, `easeOutCubic`, aligned to the top
  (`lib/api/widgets/reading_pane.dart`).

Active-heading tracking walks the outline's headings in order, measuring each
keyed heading's top against the page's top; the last one at or above the
120 px line wins (`lib/api/widgets/reading_pane.dart`,
`lib/api/widgets/reading_pane.dart`), falling back to the first heading.

## Events

None today. The **reading-pane block** slot belongs one level down, in
[Document View](12-document-view.md), where a contributor would render a fenced
language ([Plugin architecture](../07-roadmap/01-plugin-architecture.md)).

## Lifecycle

`initState` listens to the scroll controller and runs one tracking pass after
the first frame (`lib/api/widgets/reading_pane.dart`). When a different
document arrives the anchor keys are cleared, the active anchor is reset, and
after the frame the scroll jumps to the top and tracking runs again
(`lib/api/widgets/reading_pane.dart`). The controller is disposed with
the state (`lib/api/widgets/reading_pane.dart`).

Changing the text size rebuilds with a new scale; the column follows, because
it is derived rather than stored
(`test/presentation/text_size_test.dart`).

When fresh bytes arrive under the same `DocumentId`, the pane rebuilds heading
and match anchors but deliberately retains its `ScrollController` offset. Only
a different identity jumps to the top
(`lib/api/widgets/reading_pane.dart`).

## Failure and recovery

`scrollToAnchor` does nothing for an unknown anchor
(`lib/api/widgets/reading_pane.dart`); tracking skips headings with no
render box yet (`lib/api/widgets/reading_pane.dart`) and reports nothing
for a document with no headings at all
(`lib/api/widgets/reading_pane.dart`). An unavailable image is recovered by
[Document Image](23-document-image.md) inside the page rather than failing the
reading.

## Transition

Everything still builds at once inside one scroll view, which keeps
`ensureVisible` exact and remains the first thing to revisit for very long
documents. A lazy list would need anchor positions estimated ahead of layout.
