# Rich atomic-paragraph baseline

## Environment

- Flutter 3.47.1 stable, Dart 3.13.1
- macOS 26.5.2, Apple silicon
- profile build, 1280 × 820 logical-pixel viewport
- one provisional `ParagraphBlock` containing repeated plain, strong, inline-
  code and linked runs
- production `ReadingPane`, inline composition, selection and Quiet Viewport
  geometry
- command and metric definitions: `benchmark/README.md`

## Observation

The plain atomic-paragraph path is viewport-windowed, but one ordinary inline
mark returns the complete paragraph to `Paragraph` and one `RenderParagraph`.
That is common generated Markdown: a still-open answer can contain emphasis,
an identifier and a citation long before it reaches a blank-line boundary.

## Evidence

| Visible characters | Inline runs | Mounted characters | Open wall | Open frame worst | Middle-seek frame worst | RSS added |
|---:|---:|---:|---:|---:|---:|---:|
| 10,032 | 1,064 | 10,032 | 483 ms | 20.3 ms | 5.0 ms | 18.0 MiB |
| 100,056 | 10,612 | 100,056 | 781 ms | 144.2 ms | 36.1 ms | 70.1 MiB |
| 1,000,032 | 106,064 | 1,000,032 | 29.09 s | 5,280.5 ms | 236.7 ms | 660.0 MiB |

The million-character opening frame blocks for over five seconds and leaves
roughly 660 MiB of additional process memory after replacing the prior
fixture. A later seek through the unchanged paragraph still misses twenty-eight
frames on a 120 Hz display. The 29-second wall time includes framework settling
after the synchronous frame, but it is already far beyond an interactive
operation.

## Cause

`InlineComposer` correctly creates style-bearing spans for every authored run,
but `WindowedPlainParagraph` accepts only one `TextRun`. The rich paragraph
therefore gives Flutter the entire 106,064-span tree. Top-level sliver laziness
cannot subdivide one render object, so build, text shaping, retained span state
and later layout all grow with the complete atomic block.

## Required intervention

The safe boundary is not “remove rich text.” A range representation must:

- map source offsets to the active inline style and link behavior without
  walking every earlier run;
- compose only the source range needed by `AppendWrapIndex` or the mounted
  viewport;
- preserve cross-run quote context, exact shaping, widow policy, semantics,
  links, selection and authored-source copying;
- retain stable checkpoints across an adjacent streamed suffix; and
- keep rich widgets such as images and mathematics on their deliberate eager
  path until they have a separate geometry contract.

## Confidence and tradeoff

Confidence is high that this is a multiplicative rendering defect, not profile
noise: source size, span count, mounted text, frame time and memory rise
together across two orders of magnitude. No optimization has been claimed yet.
The next slice should first separate text-only inline marks from widget-bearing
runs, then prove range composition against the current eager output.

## Windowed result

`InlineRangeIndex` now records source boundaries over text-only nested inline
meaning, and `WindowedRichParagraph` projects only the range requested by the
retained visual-line index or current viewport. The eager composer still owns
the actual styles and link behavior inside that bounded range.

| Visible characters | Mounted characters | Open wall | Open frame worst | Open frame p99 | Middle-seek frame worst | RSS added |
|---:|---:|---:|---:|---:|---:|---:|
| 10,032 | 10,032 | 466 ms | 18.0 ms | 18.0 ms | 5.5 ms | 9.1 MiB |
| 100,056 | 2,706 | 673 ms | 11.7 ms | 11.7 ms | 7.2 ms | 5.2 MiB |
| 1,000,032 | 2,706 | 1.86 s | 55.2 ms | 9.2 ms | 13.2 ms | 0.4 MiB |

The million-character opening frame fell from 5,280.5 ms to 55.2 ms, a 95×
reduction. Mounted Flutter text is now constant, the retained 660 MiB process
jump disappears, and the complete paragraph extent is 514,739.8 logical
pixels—the same geometry as the eager baseline. Initial line discovery used
153 harness pumps and publishes no partial scrollbar geometry.

The range contract preserves nested marks and one link container, smart
punctuation outside code, literal punctuation inside code, exact authored-
source offsets, bidi direction, emoji, widow policy and complete semantics.
Inline widgets, mathematics and footnote controls remain deliberately eager
because they own geometry or control semantics beyond their reading text.

## Remaining cost

The range index now uses the same publication rule as the visual-line index.
An explicit depth-first builder consumes bounded node batches after the first
placeholder frame, then publishes one complete immutable source index. A rich
replacement keeps the previous exact paragraph height and scroll extent until
both its range and line indexes are complete; partial geometry never reaches
the scrollbar.

The native profile after scheduling records this million-character result:

| Mounted characters | Open wall | Worst index step | Open frame worst | Open frame p99 | Middle-seek frame worst | Exact extent |
|---:|---:|---:|---:|---:|---:|---:|
| 2,706 | 1.95 s | 7.5 ms | 43.1 ms | 11.6 ms | 17.5 ms | 514,739.8 px |

The former synchronous range-index frame no longer exists. The worst opening
frame fell another 22% from 55.2 ms while the million-character geometry and
constant mounted span count remained exact. Step timing is now emitted by the
profile harness so a future change cannot hide work by moving it out of a
Flutter frame.

This removes the multiplicative render-object and synchronous source-index
cost, but exposes one smaller shared boundary:

- a middle seek composes roughly 2,700 visible characters across hundreds of
  tiny authored runs and reaches 17.5 ms in this deliberately dense fixture;
  the first published viewport pays the same span-composition cost and remains
  the 43.1 ms opening outlier.

This is now a viewport-sized composition problem rather than million-character
text shaping. It should be compacted only with another measured pass; the
present result does not call it solved.
