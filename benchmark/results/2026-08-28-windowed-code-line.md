# Viewport-windowed code-line result

## Environment

- Flutter 3.47.1 stable, Dart 3.13.1
- macOS 26.5.2, Apple silicon
- profile build, 1280 × 820 logical-pixel viewport
- same one-line fixture and command as the committed atomic-line baseline

## Result

| Source characters | Characters at open | Characters at midpoint | Midpoint range | Worst measured frame | Horizontal extent |
|---:|---:|---:|---:|---:|---:|
| 10,000 | 10,000 | 10,000 | eager below cap | 7.5 ms | 92,598 px |
| 100,000 | 121 | 154 | 49,925–50,079 | 3.5 ms | 933,174 px |
| 1,000,000 | 154 | 154 | 499,925–500,079 | 5.4 ms | 9,338,841 px |

Sources below the 32,768-character virtualization threshold keep the ordinary
renderer, making its maximum eager work an explicit static cap. Above it, the
line retains its complete monospace coordinate space while only the horizontal
viewport plus 32 overscan columns on each edge becomes a `RenderParagraph`.

The million-character baseline mounted all one million characters, produced a
147.7 ms frame and added about 291 MiB RSS. In this run the million-character
replacement had a -0.25 MiB process RSS delta after GC and its worst measured
frame was 5.4 ms. RSS is not an allocation attribution, but the retained-memory
slope has plainly disappeared together with the mounted-character slope.

## What this proves

- Horizontal shaping, layout, paint and semantics registration are bounded by
  a fixed eager cap or the local viewport, not by an authored line's length.
- A direct seek lands around character 500,000 without shaping its prefix.
- The full 9,338,841-pixel horizontal range remains reachable; the source is
  neither wrapped nor truncated.
- Vertical and horizontal windowing compose: one giant line and 50,000 ordinary
  lines use the same outer-page physics and exact-source Copy action.

## Remaining boundaries

The source model and initial line scan still necessarily visit newly received
characters. Syntax classification currently accepts a complete immutable
source string, so a grammar can still tokenize an enormous fence in one job.
Selection is native inside the mounted two-dimensional window; crossing an
unmounted boundary needs the model-backed selection slice tracked separately.
Turning wrapping on also uses the eager renderer until wrapped-row geometry is
indexed.
