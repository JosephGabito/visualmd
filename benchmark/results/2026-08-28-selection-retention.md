# Native drag-selection retention baseline

## Reader's summary

**Problem.** Flutter's native cross-sliver selection kept every selected
paragraph widget alive after it left the viewport. Over a 3,800 px drag,
retained paragraphs grew from 19 to 54 even though only nine were visible.

**Solution.** Flutter still owns pointer interaction, auto-scroll, and visible
highlighting, while `ModelSelectionSnapshot` owns the durable document range
and assembles Copy from the source model.

**Before and after.** At the longest drag, retained paragraphs fall from 54 to
15 and stay flat across increasing selection distance. Copied content still
grows with the selected model range, and wall time remains essentially
unchanged at 10.18 versus 10.19 seconds because the native auto-scroll journey
itself is intentionally the same.

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

## Model-owned range comparison

The same profile journey was repeated after each mounted block began recording
its local source range in `ModelSelectionSnapshot` and the sliver stopped
automatically retaining selected children.

| Drag frames | Scroll distance | Copied characters | Visible paragraphs | Retained paragraphs | Wall time |
|---:|---:|---:|---:|---:|---:|
| 60 | 815 px | 1,828 | 9 | 15 | 2.70 s |
| 180 | 2,000 px | 3,480 | 9 | 15 | 5.69 s |
| 360 | 3,800 px | 5,958 | 9 | 15 | 10.19 s |

Copy still grows with the selected document range, but widget retention is
flat across a 4.7x increase in scroll distance. The small copied-character
difference from the native baseline comes from assembling the canonical model
text with its authored block separators rather than asking disposed render
objects for a fragment. RSS deltas were 28.8, 0.0, and -0.9 MiB and remain
allocator-sensitive.

This proves the repair separates the two costs: selection data is proportional
to selected blocks, while render, element, layout, paint, and semantics state
remain proportional to the viewport. Flutter continues to own the pointer
gesture, auto-scroll, and visible highlight. The model owns only the durable
range and Copy result.
