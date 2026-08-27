# Viewport-windowed code-block result

## Environment

- Flutter 3.47.1 stable, Dart 3.13.1
- macOS 26.5.2, Apple silicon
- profile build, 1280 × 820 logical-pixel viewport
- same fixture and command as the committed atomic baseline

## Result

The code surface now retains a lightweight line-start index and mounts only
the page viewport plus eight overscan lines on each edge. Its complete height
still belongs to the outer document; seeking does not enter a nested vertical
scroll view.

| Lines | Rows at open | Rows at midpoint | Midpoint source range | Open worst frame | Midpoint worst frame |
|---:|---:|---:|---:|---:|---:|
| 1,000 | 46 | 54 | 473–526 | 7.9 ms | 7.8 ms |
| 10,000 | 46 | 54 | 4,973–5,026 | 4.9 ms | 9.0 ms |
| 50,000 | 46 | 54 | 24,973–25,026 | 31.7 ms | 14.5 ms |

The 50,000-line baseline produced a 513 ms frame and added about 771 MiB RSS.
The windowed run's measured RSS deltas were approximately 6.7 MiB, 0 MiB and
-1.2 MiB in sequence; process-level GC makes the latter two unsuitable as
allocation counts, but it establishes that retained memory no longer follows
the prior 20/194/771 MiB line-count slope.

The one-time 31.7 ms 50,000-line open frame includes the linear scan needed to
locate all 49,999 newline boundaries in a newly opened 3.3-million-character
block. That initial cost grows with the new input, as expected. A direct seek
to the middle remains below one 60 Hz frame and composes only 54 rows.

## What this proves

- Vertical text layout, paint and semantics registration are bounded by the
  viewport rather than by the number of lines in one fence.
- Direct geometry seeks land on the source window around the target, including
  line 25,000 of the largest fixture.
- The outer document retains the complete 1,099,650-pixel scroll extent; no
  truncation or second vertical scrolling model was introduced.
- Syntax and search composition can operate on a source range without walking
  the preceding token prefix.
- Whole-block copy still reads the exact source model, independent of which
  rows happen to be mounted.

## Remaining boundaries

This result isolates multiline, unwrapped code. A single enormous source line
can still hand one enormous horizontal paragraph to Flutter. Turning wrapping
on also returns to the eager renderer because wrapped row geometry is not yet
indexed. Model-backed selection across an unmounted line window and bounded
syntax tokenization are subsequent slices; the renderer does not pretend that
visible-row virtualization solves those contracts.
