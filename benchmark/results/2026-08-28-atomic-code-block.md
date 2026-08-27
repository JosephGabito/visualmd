# Atomic code-block baseline

## Environment

- Flutter 3.47.1 stable, Dart 3.13.1
- macOS 26.5.2, Apple silicon
- profile build, 1280 × 820 logical-pixel viewport
- one top-level fenced Dart block rendered by the production `ReadingPane`
- command and metric definitions: `benchmark/README.md`

## Result

Top-level sliver laziness cannot subdivide one Markdown block. The existing
code renderer therefore gives Flutter one `Text.rich` containing every line.
The profile run exposes the resulting shaping, layout, and retained-memory
slope:

| Lines | Source characters | Open wall time | Worst frame | RSS added | Scroll extent |
|---:|---:|---:|---:|---:|---:|
| 1,000 | 62,779 | 466 ms | 22 ms | 19.9 MiB | 21,660 px |
| 10,000 | 647,779 | 463 ms | 116 ms | 194.3 MiB | 219,642 px |
| 50,000 | 3,327,779 | 900 ms | 513 ms | 771.3 MiB | 1,099,650 px |

RSS is the process delta around each sequential replacement, so it is a
practical retention signal rather than a heap-allocation attribution. The
nearly linear growth and half-second 50,000-line frame are large enough that
allocator noise cannot change the conclusion.

The open wall clock includes framework settling and asynchronous highlighting;
the frame sample isolates the synchronous build/layout/paint stall. Raster
time was negligible in this run. Text shaping and layout, rather than GPU fill,
is the dominant boundary.

## What this proves

- A long code fence defeats the otherwise viewport-bounded document renderer.
- Correctly estimating its million-pixel extent is not sufficient: the current
  child eagerly materializes the text used to fill that extent.
- Ordinary generated prose is already independent of committed document
  length, but a generated answer can still create an unbounded frame by leaving
  one fence open.
- The next implementation must preserve exact source, selection, copy,
  highlighting, accessibility, and outer-page scrolling while making mounted
  code layout proportional to the visible line window.

## Acceptance boundary

The replacement should rerun this same fixture. At 50,000 lines, mounted code
rows and synchronous layout work must remain viewport-bounded, the outer scroll
extent must still represent the complete block, and copying must return all
3,327,779 authored characters. A solution that truncates source or introduces
an independently scrolling code editor does not satisfy the reader contract.
