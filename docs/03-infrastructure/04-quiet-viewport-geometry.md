# Quiet Viewport Geometry

## Purpose and boundary

Quiet viewport geometry makes an incrementally changing document behave like a
stable physical page. It owns prefix extents, revision-safe measurements,
anchor compensation, and scrollbar geometry frozen for one visible
interaction. It does not parse Markdown, decide block identity, build widgets,
or choose typography.

The reusable algorithm is a pure-Dart package at `packages/quiet_viewport`.
Visual MD's infrastructure adapter translates between that package and the
application-owned `DocumentViewportGeometry` port
(`lib/infrastructure/viewport/quiet_document_viewport_geometry.dart`). Neither
the domain nor presentation ring imports the package.

## Present wiring

The composition root creates one `QuietDocumentViewportGeometryFactory` and
passes the application contract through `VisualMdApp`, `ReaderScreen`, and
`ReadingPane` (`lib/main.dart`, `lib/api/app.dart`,
`lib/api/screens/reader_screen.dart`, `lib/api/widgets/reading_pane.dart`).

`QuietScrollbar` captures the actual scrollable content and viewport extents
through that factory when an interaction begins. It retains the frozen metrics
until its thumb has completely faded. Appending a tail while the thumb is
visible therefore changes neither thumb length nor its coordinate system
(`lib/api/widgets/quiet_scrollbar.dart`).

The same adapter supplies the block-level extent ledger to
`GeometrySliverList`. The sliver seeks directly to the block occupying a
content offset, lays out only its cache window, replaces estimates with real
render-box extents, and returns Flutter's native `scrollOffsetCorrection`
before paint when measured geometry changed above the reader
(`lib/api/render/geometry_sliver_list.dart`). The scrollbar absorbs that same
correction as non-user movement, so the page and thumb keep one coordinate
system (`lib/api/widgets/reading_pane.dart`,
`lib/api/widgets/quiet_scrollbar.dart`).

## Inputs and outputs

The ledger receives stable keys, item revisions, a layout revision, and
nonnegative estimated or measured extents. It returns prefix positions and an
`ExtentCorrection`: the change in total content extent and the exact change
before the selected anchor (`packages/quiet_viewport/lib/src/extent_ledger.dart`).

For item extents `hᵢ`, the leading coordinate of item `k` is
`H(k) = Σ hᵢ` for `i < k`. If improved measurements change the prefix by `Δ`,
the compensated scroll position is `p′ = p + Δ`. The viewport coordinate is
then `H′(k) - p′ = H(k) + Δ - (p + Δ) = H(k) - p`: the anchor cannot move.

The frozen scrollbar captures content extent `C` and viewport extent `V`.
Its thumb length is `track × V / C`, subject to a minimum. During that epoch,
tail growth does not change `C`; a layout correction is accumulated as bias
and subtracted from physical pixels before progress is calculated
(`packages/quiet_viewport/lib/src/frozen_scroll_metrics.dart`).

## Events

None. The package and adapter are synchronous state machines. Flutter scroll
notifications begin, update, and end an interaction at the API edge; no domain
or application event is published (`lib/api/widgets/quiet_scrollbar.dart`).

## Lifecycle

A scrollbar geometry epoch begins with the first scroll update or thumb drag.
Repeated updates reuse it. Scroll end schedules a fade, and only a fully hidden
thumb releases the frozen metrics; a new gesture during the fade cancels that
release and continues in the same coordinate system.

A block ledger belongs to one document and layout lifetime. Appends extend its
Fenwick tree in `O(log n)`, stable-key lookup is `O(1)`, and prefix position,
measurement, and offset lookup are `O(log n)`. A width, type, or theme change
starts a new layout revision rather than accepting stale measurements. A
provisional suffix replacement truncates only that suffix, retains every
measured prefix extent, and validates incoming identity without reconstructing
a prefix set. Its work is proportional to the removed and inserted suffix, not
the document. A general snapshot reconciliation retains measured extents for
every stable ID whose item revision is unchanged; revised records receive fresh
estimates. Thus a refresh does not throw away geometry already learned from the viewport
(`lib/infrastructure/viewport/quiet_document_viewport_geometry.dart`).

## Failure and recovery

Duplicate identities, unknown identities, invalid extents, and revisions that
do not advance throw before mutating the ledger. A stale asynchronous measure
returns `null` and cannot change geometry. An empty ledger can change layout
epochs safely. The Flutter thumb clamps frozen targets to the live scroll
position, so shrinking content cannot send a drag outside current bounds.

The package proofs live in `packages/quiet_viewport/test`, including retained
measurement and lookup after suffix replacement. Visual MD verifies the adapter
in `test/infrastructure/quiet_document_viewport_geometry_test.dart`.
`test/presentation/geometry_sliver_list_test.dart` proves direct far seeking,
pre-paint measurement correction, and stable layout-epoch changes.
`test/presentation/quiet_scrollbar_test.dart` proves both tail growth and a
physical anchor correction leave a visible thumb exactly unchanged.

## Transition

Geometry correction and provisional-tail replacement are live. Large atomic
containers, incremental outline projection, and full-document select-all still
need specialised policies; none require changing the geometry package's
identity, prefix-sum, or frozen-metric contracts.
