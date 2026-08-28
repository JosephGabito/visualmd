# Atomic provisional-paragraph virtualization

## Environment

- Flutter 3.47.1 stable, Dart 3.13.1
- macOS 26.5.2, Apple silicon
- profile build, 1280 × 820 logical-pixel viewport
- one provisional `ParagraphBlock` rendered by the production `ReadingPane`
- exact reading typography and Quiet Viewport geometry enabled
- command and metric definitions: `benchmark/README.md`

## Eager baseline

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

## Windowed result

The repaired provisional path asks Flutter's `TextPainter` for exact visual
line boundaries in bounded source windows. It retains those boundaries across
an upstream-proven append, reports the complete paragraph height to the outer
document, and mounts only the lines near that viewport:

| Source characters | Characters mounted | Index step worst | Initial frame worst | Middle-seek worst | Append worst | Finalize worst | Movement | RSS added |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 10,000 | 10,000 | — | 7.7 ms | 2.8 ms | 7.3 ms | 4.6 ms | 0 px | 4.8 MiB |
| 100,000 | 1,994 | 2.8 ms | 3.2 ms | 3.3 ms | 2.4 ms | 1.9 ms | 0 px | 15.9 MiB |
| 1,000,000 | 2,477 | 1.1 ms | 4.6 ms | 3.3 ms | 4.1 ms | 7.8 ms | 0 px | 66.4 MiB |

Ten thousand characters deliberately remains on the ordinary eager path. At
the two pathological sizes, mounted text is constant; initial reveal, a deep
seek, adjacent stream append and safe finalization all remain below the 8.3 ms
frame budget of a 120 Hz display. The append does not move a reader parked in
the middle.

Initial construction still performs O(source) work: a pre-existing
million-character paragraph needs 245 bounded `TextPainter` operations to
discover all line boundaries. No operation receives more than 4,161 code units
or takes more than 1.1 ms in that run. Work starts after the placeholder frame,
yields between batches, and publishes no partial height; a replacement retains
its previous exact geometry until the new index is complete. The old 237 ms
synchronous frame is therefore gone without making a false O(1) construction
claim. The 66 MiB process delta is not yet a memory plateau proof.

## What this proves

- A visual-line index can retain Flutter's exact wrapping while making mounted
  layout and deep access proportional to the viewport.
- An adjacent append revisits only the previous unfinished line and the new
  suffix; the million-character prefix contributes no text-layout work.
- The paragraph's complete height remains exact, and a tail append moves a
  reader above it by exactly zero pixels.
- First-load discovery is cooperatively scheduled in bounded operations, while
  scrollbar geometry changes once from unpublished to exact rather than
  walking through partial estimates.
- Safe finalization binds the widow by re-resolving only its owning line;
  counting eligibility stops after four words instead of allocating a complete
  word list.
- Total first-load work, punctuation that changes shaping, and rich-inline
  paragraphs remain distinct costs rather than hidden claims.

## Acceptance boundary

The current fast path is deliberately for one large plain-text run with no
active search decoration and no first-line indent. It preserves authored
source, Flutter line breaking, model-backed selection offsets, complete
semantics, reading direction, exact height, widow binding, scrollbar geometry
and outer-page scrolling through a safe finish event.

Straight quotes, dash runs and ellipses still use the eager final composer
because their glyph advances or visible length can change throughout the
paragraph. The next slice must carry exact source-to-glyph offsets through a
range projection before those paragraphs can retain the window safely.
