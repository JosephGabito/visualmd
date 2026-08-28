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

## Exact rich viewport

Plain text retains eight inexpensive lines beyond each viewport edge. Styled
text has a different cost: each speculative line carries authored span and
recognizer state. The rich window now uses the exact floor/ceil-covered visual
lines with no extra overscan. Scroll-position listeners update the range before
paint, and a widget proof checks that its mounted rectangle covers both edges
of the viewport after a deep jump.

| Visible characters | Mounted characters | Open wall | Worst index step | Open frame worst | Open frame p99 | Middle-seek frame worst | Exact extent |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 1,000,032 | 1,650 | 2.00 s | 8.9 ms | 39.1 ms | 14.0 ms | 15.0 ms | 514,739.8 px |

This removes 39% of the retained styled text from the prior 2,706-character
window. In the 100,056-character fixture the middle seek falls from 8.2 ms to
3.2 ms; the deliberately dense million-character fixture falls from 17.5 ms
to 15.0 ms. The complete extent remains bit-for-bit unchanged, so this changes
retained span work rather than scrollbar physics.

## Rich stream-append baseline

Viewport bounding does not by itself make a rich paragraph streamable. The
same native journey now appends one 51-character suffix containing plain,
strong and inline-code runs while the reader is parked halfway through the
paragraph:

| Existing characters | Appended | Append wall | Indexing pumps | Worst index step | Append frame worst | Mounted after | Scroll delta |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 10,032 | 51 | 683 ms | 0 | 0 ms | 18.1 ms | 10,083 | 0 px |
| 100,056 | 51 | 674 ms | 0 | 7.8 ms | 7.1 ms | 1,650 | 0 px |
| 1,000,032 | 51 | 1.96 s | 119 | 7.4 ms | 37.9 ms | 1,650 | 0 px |

The parked reader and constant mounted span count prove that presentation no
longer scales with the complete paragraph. The append wall time and 119 pumps
prove a different defect: an unproven rich revision reconstructs the complete
source-range index and complete line index before atomic publication. Repeating
that work for token-sized AI deltas is quadratic in the generated paragraph.
The next intervention needs a parser-owned inline append proof and retained
range/line indexes; lowering another widget constant cannot solve this slope.

## Retained rich-index append

The incremental parser now advertises `BlockInlineAppend` only when the prior
top-level inline tree remains exact. `InlineRangeIndex` appends the proven
leaves through a persistent sequence, and `WindowedPlainParagraph` rewraps the
old final visual line plus the new suffix. Both retained indexes advance to the
same revision before the viewport observes them.

| Existing characters | Appended | Append wall | Indexing pumps | Append frame worst | Mounted after | Scroll delta |
|---:|---:|---:|---:|---:|---:|---:|
| 10,032 | 51 | 683 ms | 0 | 21.2 ms | 10,083 | 0 px |
| 100,056 | 51 | 657 ms | 0 | 5.4 ms | 1,650 | 0 px |
| 1,000,032 | 51 | 691 ms | 0 | 25.0 ms | 1,650 | 0 px |

The small fixture deliberately remains below the 32,768-character windowing
threshold. For windowed rich paragraphs, the million-character revision no
longer takes 119 scheduled index pumps: retained range and line work completes
in the update frame, and the exact parked scroll position remains unchanged.
The wall measurement has a roughly 650 ms harness floor from settlement and
timing collection, so frame time is the useful remaining slope.

That frame still grows from 5.4 ms at 100,056 characters to 25.0 ms at
1,000,032. Inspection locates whole-block work outside the retained indexes:
document offsets and geometry estimates request `block.text`, and paragraph
eligibility walks the complete inline tree again. The next slice must retain
those facts alongside the revision. This pass therefore proves suffix-bounded
rich indexes, not yet an end-to-end constant-cost document revision.

## Retained block facts

`DocumentBlock` now carries exact visible code-unit and authored-line-break
counts. The parser extends them from a proven suffix; the page consumes them
for navigation offsets and geometry seeds. The sliver index also retains the
prior paragraph's range eligibility, so a proven inline append checks only its
new runs.

| Existing characters | Appended | Append wall | Indexing pumps | Append frame worst | Mounted after | Scroll delta |
|---:|---:|---:|---:|---:|---:|---:|
| 10,032 | 51 | 691 ms | 0 | 18.1 ms | 10,083 | 0 px |
| 100,056 | 51 | 657 ms | 0 | 3.5 ms | 1,650 | 0 px |
| 1,000,032 | 51 | 663 ms | 0 | 8.7 ms | 1,650 | 0 px |

The former presentation-level whole-prefix walks accounted for roughly two
thirds of the million-character append frame: removing them lowers 25.0 ms to
8.7 ms. The 5.2 ms difference between the 100k and 1M windowed fixtures is now
the narrower flat-source boundary. `InlineRangeIndex.append` must still create
one accumulated `String`, because the retained paragraph and semantics APIs
currently accept a flat string. The parser benchmark must separately include
provisional-tail parsing before the complete AI-streaming path can be called
constant-cost.

## Rich provisional-parser baseline

The same native harness now measures the actual incremental Markdown session,
not only a preconstructed domain revision. One open paragraph repeats ordinary
strong, inline-code and link syntax, then receives a 57-character suffix with
strong and inline-code runs:

| Existing Markdown | Appended | Initial parse | Append parse | Parsed on append | Runs after | Proven runs |
|---:|---:|---:|---:|---:|---:|---:|
| 10,070 | 57 | 11.7 ms | 8.5 ms | 10,127 | 641 | 5 |
| 100,035 | 57 | 119.7 ms | 105.0 ms | 100,092 | 6,323 | 5 |
| 1,000,065 | 57 | 6.87 s | 7.10 s | 1,000,122 | 63,167 | 5 |

The renderer's million-character append now builds in 8.7 ms, but producing
that revision takes 7.10 seconds. The session reparses the complete provisional
tail and `_inlineAppend` then compares the complete prior inline prefix to
recover five suffix runs. Repeating this for token-sized publications is
quadratic. This is now the dominant end-to-end stream hazard and the next
contract boundary; the numbers above are the proof before changing it.
