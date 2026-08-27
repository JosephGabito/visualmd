# Native drag-selection retention baseline

## Environment

- Flutter 3.47.1 stable, Dart 3.13.1
- macOS 26.5.2, Apple silicon
- profile build
- production `ReadingPane`, geometry sliver, and native `SelectionArea`
- 5,000 uniform paragraph blocks
- command and metric definitions: `benchmark/README.md`

## Journey

A precise mouse begins selecting in the first paragraph and remains 200 logical
pixels beyond the lower reading edge. Flutter's selection auto-scroller owns
the motion for a fixed 60, 180, or 360 frames. Copy then verifies how much text
the gesture actually selected. The mounted count sees the current viewport;
the retained count also sees offstage sliver children kept alive by selection.

## Result

| Drag frames | Scroll distance | Copied characters | Visible paragraphs | Retained paragraphs | Wall time |
|---:|---:|---:|---:|---:|---:|
| 60 | 800 px | 1,798 | 9 | 19 | 2.69 s |
| 180 | 2,000 px | 3,422 | 9 | 33 | 5.67 s |
| 360 | 3,800 px | 5,858 | 9 | 54 | 10.18 s |

RSS deltas were 30.1, 10.1, and 6.8 MiB. Those process snapshots are
allocator-sensitive and do not form a useful slope. Widget retention does: the
painted viewport stays at eight or nine paragraphs while offstage retained
paragraphs grow with the selected distance.

## What this proves

Flutter's native selection is correct across the lazy reading surface, and the
scrollbar remains independent of the selection gesture. Its correctness uses
the framework's selection-aware automatic keep-alive: blocks crossed by the
selection remain in the element tree after they leave the viewport. That turns
an arbitrarily long pointer selection into work and retained state proportional
to the selected range rather than the visible range.

The repair therefore cannot be `addAutomaticKeepAlives: false`; that would
remove the state carrying native selection and make copy incomplete. Visual MD
needs a model-owned document range, mounted native-looking highlights, and
copy assembled from the model. The native gesture remains the interaction
reference, but the model—not an offstage widget chain—must own what survives.
