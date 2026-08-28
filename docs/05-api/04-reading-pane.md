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
current scale, reading mode, `onLink` and `onActiveHeadingChanged` bound
(`lib/api/screens/reader_screen.dart`).

The build (`lib/api/widgets/reading_pane.dart`):

- A `QuietScrollbar` over one `CustomScrollView`, padded 48 px at the sides on
  ordinary windows and 24 px below 600 px, then in lines vertically — one and
  a half above, six below, so the last paragraph is never pinned to the bottom
  edge. The thumb freezes its content extent for the complete visible
  interaction, so a streamed tail cannot resize or relocate it under the
  pointer (`lib/api/widgets/reading_pane.dart`,
  `lib/api/widgets/quiet_scrollbar.dart`).
- A `ModelBackedSelectionArea` around the scroll surface. Flutter owns the
  pointer gesture, auto-scroll, and mounted highlight. Each mounted block
  records its local source range before disposal, so Copy can assemble a long
  drag from compact model ranges without retaining offstage widgets. Select All
  snapshots `DocumentContent.text`, forwards to Flutter for visible feedback,
  and includes blocks which never mounted with the model's authored separators
  (`lib/api/widgets/model_backed_selection_area.dart`,
  `lib/api/widgets/reading_pane.dart`).
- A `ReadingTheme` built once per frame from the palette, selected proportional
  role, faces and scale (`lib/api/widgets/reading_pane.dart`). See
  [Reading Theme](14-reading-theme.md).
- The breadcrumb and any stand-in title inside a `SizedBox` of
  `theme.proseWidth`, because everything on the page should hang off one left
  edge rather than centring on the window
  (`lib/api/widgets/reading_pane.dart`).
- A stand-in H1 with `document.title` when the document has no level-1 heading
  of its own, so the page is never headless
  (`lib/api/widgets/reading_pane.dart`,
  `lib/api/widgets/reading_pane.dart`).
- One `SliverDocumentView` for the whole document. It materialises only the
  viewport and cache region rather than the corpus. Its extent corrections are
  forwarded to the scrollbar's frozen interaction epoch
  (`lib/api/widgets/reading_pane.dart`,
  `lib/api/render/document_view.dart`).

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

In: `reading` (document, outline and content), `imageLoader`, `scale`, `mode`, the
application-owned `viewportGeometry` factory, `onLink`, and
`onActiveHeadingChanged` (`lib/api/widgets/reading_pane.dart`).

Out:

- `onLink(href)` — passed to `DocumentView`, raised by the
  [Inline Composer](13-inline-composer.md) when a link is tapped
  (`lib/api/widgets/reading_pane.dart`).
- `onActiveHeadingChanged(heading)` whenever the heading nearest the top
  changes (`lib/api/widgets/reading_pane.dart`).
- `scrollToAnchor(anchor)`, called by the shell: an already mounted explicit
  or heading anchor uses `Scrollable.ensureVisible`. A distant lazy anchor is
  materialised from the geometry ledger's prefix position without proportional
  retries, then its real render box supplies the exact alignment. The final
  motion is 320 ms, `easeOutCubic`, aligned to the top. Search-result navigation
  uses the same route with a quieter 220 ms duration and 0.18 alignment. Reduce
  Motion gives both paths a zero-duration alignment rather than walking the
  reader through the intervening document
  (`lib/api/widgets/reading_pane.dart`,
  `test/presentation/reading_pane_refresh_test.dart`).

Active-heading tracking visits only heading widgets mounted in the viewport
and cache region. The last one at or above the 120 px line wins; between
headings the previous active identity is retained. Its per-scroll work is
therefore bounded by visible content rather than total heading count
(`lib/api/widgets/reading_pane.dart`,
`lib/api/render/document_view.dart`).

## Events

None today. The **reading-pane block** slot belongs one level down, in
[Document View](12-document-view.md), where a contributor would render a fenced
language ([Plugin architecture](../07-roadmap/01-plugin-architecture.md)).

## Lifecycle

`initState` listens to the scroll controller and runs one tracking pass after
the first frame (`lib/api/widgets/reading_pane.dart`). When a different
document arrives both navigation-key maps are cleared, the active heading is
reset, and
after the frame the scroll jumps to the top and tracking runs again
(`lib/api/widgets/reading_pane.dart`). The controller is disposed with
the state (`lib/api/widgets/reading_pane.dart`).

Changing the text size rebuilds with a new scale; the column follows, because
it is derived rather than stored
(`test/presentation/text_size_test.dart`).
Changing reading mode rebuilds the same document at the same scroll position;
the active face supplies a newly measured column and beat
(`lib/api/widgets/reading_pane.dart`,
`test/presentation/reading_scale_test.dart`).

When revisioned content changes only its suffix beneath the same `DocumentId`,
the pane truncates its derived navigation arrays at that boundary and visits
only replacement records while retaining its exact `ScrollController` offset.
A suffix containing headings or explicit anchors currently takes the safe full
navigation rebuild because outline projection is not incremental yet. A
non-tail replacement also rebuilds navigation but retains the offset. Only a
different document identity jumps to the top. A reader already at the tail remains pinned while the lazy sliver
converges on its new maximum; a reader anywhere above it never enters that path
(`lib/api/widgets/reading_pane.dart`).

Before a non-append mutation, the pane identifies the stable block at the
viewport's leading edge. Reconciliation retains measured extents for unchanged
revisions and schedules the changed prefix as a one-shot pre-paint correction.
The correction moves the physical scroll position by exactly the prefix delta;
the anchor's screen coordinate is unchanged
(`lib/api/widgets/reading_pane.dart`,
`lib/api/render/geometry_sliver_list.dart`).

The quiet scrollbar captures one logical coordinate system when scrolling
starts and releases it only after the thumb fades. Metrics updates during that
epoch cannot alter its extent. Dragging maps thumb travel through the frozen
maximum and then clamps against the live position, so the control remains
interactive even while the tail grows. A drag or overscroll that reaches the
tail records reader intent until the bounded geometry-convergence window ends,
so learning the final extents cannot leave a tail follower behind
(`lib/api/widgets/quiet_scrollbar.dart`,
`lib/api/widgets/reading_pane.dart`).
Reduce Motion shows and hides the thumb without an opacity tween while keeping
the delay, frozen epoch, scrolling, and direct thumb dragging unchanged
(`lib/api/widgets/quiet_scrollbar.dart`,
`test/presentation/quiet_scrollbar_test.dart`).

Pointer selection is reset by a new primary-button gesture or native selection
clear. A block range remains in `ModelSelectionSnapshot` when its lazy widget is
disposed and is removed when the mounted block reports no selection. Switching
`DocumentId` clears the snapshot; appending to the same identity preserves the
selected end. Copy reads those ranges in document order without notifying or
rebuilding the page (`lib/api/widgets/model_backed_selection_area.dart`,
`lib/api/render/document_view.dart`).

## Failure and recovery

`scrollToAnchor` does nothing for an unknown anchor
(`lib/api/widgets/reading_pane.dart`); a known distant anchor is first mounted
at its ledger coordinate and then aligned to its render box. Tracking reports nothing
for a document with no headings at all
(`lib/api/widgets/reading_pane.dart`). An unavailable image is recovered by
[Document Image](23-document-image.md) inside the page rather than failing the
reading.

## Transition

Viewport work, tail indexing, far navigation, and geometry correction are
bounded, and visible scrollbar geometry is frozen against both tail growth and
automatic physical correction. Select All and Copy are model-backed without
remounting the page. The selected snapshot deliberately keeps its original end
when a stream appends, matching a stable selection rather than silently
claiming new words. Long pointer selection retains compact source ranges rather
than one render subtree per crossed block; the selection benchmark holds the
retained paragraph count flat while copied text grows across the document
(`benchmark/results/2026-08-28-selection-retention.md`). Semantic reading order
across an unmounted span remains a separate accessibility boundary.
