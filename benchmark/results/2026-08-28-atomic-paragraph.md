# Atomic provisional-paragraph baseline

## Environment

- Flutter 3.47.1 stable, Dart 3.13.1
- macOS 26.5.2, Apple silicon
- profile build, 1280 × 820 logical-pixel viewport
- one provisional `ParagraphBlock` rendered by the production `ReadingPane`
- exact reading typography and Quiet Viewport geometry enabled
- command and metric definitions: `benchmark/README.md`

## Result

Top-level sliver laziness cannot subdivide a paragraph. Flutter receives one
`RenderParagraph` containing every character, so both shaping and retained
text state grow with an unfinished AI tail:

| Source characters | Characters mounted | Open wall time | Worst frame | Middle-seek frame | RSS added |
|---:|---:|---:|---:|---:|---:|
| 10,000 | 10,000 | 450 ms | 7.6 ms | 2.8 ms | 31.1 MiB |
| 100,000 | 100,000 | 493 ms | 34.9 ms | 19.3 ms | 34.5 MiB |
| 1,000,000 | 1,000,000 | 532 ms | 233.8 ms | 97.8 ms | 291.9 MiB |

Open wall time includes framework settling. The frame samples isolate the
synchronous visible stall: 100,000 characters already miss a 60 Hz frame, and
one million characters consume about 28 frames at a 120 Hz budget. RSS is the
process delta around sequential replacements, so it is an allocator-sensitive
retention signal rather than a Dart-heap attribution; the 292 MiB final jump is
large enough that noise does not change the conclusion.

## What this proves

- `O(visible top-level blocks)` is insufficient when one visible block owns an
  unbounded shaped text object.
- Incremental parsing and one-record suffix mutation do not protect the frame
  after the provisional paragraph reaches Flutter.
- Jumping within the already-mounted paragraph also develops an unbounded
  frame, so fast initial display alone would not solve deep access.
- The problem is text shaping, layout and retained paragraph state, not GPU
  fill or committed-prefix traversal.

## Acceptance boundary

The replacement must make mounted text and interactive work proportional to a
line window while preserving exact authored source, final typography, links,
selection, copy, accessibility, reading direction, search offsets, scrollbar
geometry and outer-page scrolling. It may specialize the provisional state,
but finalization must not twitch the reader or silently change line breaks.

This is a harder problem than monospace code virtualization because prose has
variable advances, inline semantics, bidirectional runs and no authored line
boundaries. The benchmark therefore records the failure without pretending
that arbitrary string chunking is an acceptable repair.
