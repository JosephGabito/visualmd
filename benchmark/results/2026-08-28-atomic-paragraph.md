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

| Source characters | Characters mounted | Initial worst frame | Middle-seek worst | Append worst | Append movement | RSS added |
|---:|---:|---:|---:|---:|---:|---:|
| 10,000 | 10,000 | 6.9 ms | 1.4 ms | 6.4 ms | 0 px | 34.6 MiB |
| 100,000 | 2,474 | 43.3 ms | 3.2 ms | 1.6 ms | 0 px | 12.7 MiB |
| 1,000,000 | 2,477 | 238.3 ms | 3.7 ms | 3.6 ms | 0 px | 66.4 MiB |

Ten thousand characters deliberately remains on the ordinary eager path. At
the two pathological sizes, mounted text is constant and both a deep seek and
an adjacent stream append stay below 4 ms. The one-million-character append is
about 65 times cheaper than the initial full indexing frame and does not move
the reader parked in the middle.

Initial construction is still O(source): a pre-existing million-character
paragraph must discover its line boundaries once, and that synchronous pass is
still a 238 ms frame. Its peak process delta is substantially lower than the
eager paragraph's 292 MiB, but 66 MiB is not a memory plateau proof. This slice
solves repeated stream updates and interactive access; it does not claim that
opening a pathological completed blob is constant-time.

## What this proves

- A visual-line index can retain Flutter's exact wrapping while making mounted
  layout and deep access proportional to the viewport.
- An adjacent append revisits only the previous unfinished line and the new
  suffix; the million-character prefix contributes no text-layout work.
- The paragraph's complete height remains exact, and a tail append moves a
  reader above it by exactly zero pixels.
- Initial full-source indexing, final typographic punctuation/widow treatment,
  and rich-inline paragraphs remain distinct costs rather than hidden claims.

## Acceptance boundary

The next boundary is finalization. The current fast path is deliberately only
for one large provisional plain-text run with no active search decoration and
no first-line indent. It preserves authored source, Flutter line breaking,
model-backed selection offsets, complete semantics, reading direction, exact
height, scrollbar geometry and outer-page scrolling. Final typography still
uses the eager composer, so a pathological finalization can pay the complete
cost once.

The next slice must extend range composition to typographic punctuation and
rich inline semantics, then retain the window through provisional-to-committed
transition without changing the final line breaks or selection coordinates.
