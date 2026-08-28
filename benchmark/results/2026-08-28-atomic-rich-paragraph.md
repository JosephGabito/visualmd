# Streamable rich paragraph: baseline to stable suffix

## Problem

An AI response can remain one provisional Markdown paragraph for a long time.
As soon as it contains emphasis, code or a link, the old reader mounted and
reparsed the complete paragraph on every publication. At one million
characters, opening blocked a Flutter frame for 5.28 seconds and appending a
57-character Markdown suffix spent 7.10 seconds reparsing the prefix. Repeating
that work for token-sized updates is quadratic.

## Solution

The reader now treats rendering and parsing as two retained indexes. Flutter
mounts only the exact rich-text viewport while persistent range, line and block
facts extend from a parser-owned suffix proof. The incremental parser keeps a
stable inline checkpoint and sends only the unresolved tail through
`package:markdown`. Ambiguous Markdown deliberately falls back to the complete
parser, and no partial geometry is ever published to the scrollbar.

## Before and after at one million characters

| Boundary | Before | After |
|---|---:|---:|
| Rich characters mounted by Flutter | 1,000,032 | 1,650 |
| Worst opening frame | 5,280.5 ms | 39.1 ms |
| Indexing pumps after a 51-character rich append | 119 | 0 |
| Worst append frame | 37.9 ms | 8.7 ms |
| Parse time for a 57-character Markdown append | 7.10 s | 0.133 ms |
| Source characters parsed for that append | 1,000,122 | 58 |
| Scroll delta during append | 0 px | 0 px |

The closed-suffix path is now bounded by the incoming source after an accepted
single-line checkpoint. Initial parsing remains O(source). A later section
shows the next boundary honestly: growing or closing an unresolved inline tail
parses bounded source but still scans the retained run prefix to construct its
mutation. The sections below keep each intermediate baseline so the result can
be reproduced rather than merely asserted.

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

## Stable inline checkpoints

The incremental session now retains a parsed inline prefix at conservative
single-line checkpoints. A checkpoint is accepted only after whitespace when
code spans, emphasis/strong/strikethrough delimiters, brackets and parentheses
are closed. Raw HTML, character references, line breaks and any ambiguous
delimiter state keep the complete-parser fallback. Between checkpoints, only
the unresolved inline tail is reparsed through `package:markdown`'s ordinary
inline parser; the block grammar and retained prefix are not revisited.

| Existing Markdown | Appended | Append parse | Parsed on append | Runs after | Proven runs |
|---:|---:|---:|---:|---:|---:|
| 10,070 | 57 | 0.091 ms | 58 | 642 | 5 |
| 100,035 | 57 | 0.075 ms | 58 | 6,324 | 5 |
| 1,000,065 | 57 | 0.133 ms | 58 | 63,168 | 5 |

The million-character append falls from 7.10 seconds to 0.133 ms—more than
53,000× faster—and its parsed input is constant at the 57-character suffix plus
the one retained boundary space. The 10k, 100k and 1M results have no positive
prefix slope. The initial parse remains necessarily O(source), and the native
fixture still records 7.10 seconds for opening this deliberately dense
million-character Markdown paragraph. Multi-line block reinterpretation and
ambiguous inline tails remain explicit fallbacks rather than being called
constant work.

## Unresolved inline-tail baseline

The stable checkpoint makes source parsing suffix-bounded, but the next
publication contract still assumes that an inline tree either appends or is
replaced in full. The harness therefore pauses inside `**unfinished`, grows
that unresolved text by 10 characters, then appends 14 characters which close
the emphasis. Both operations parse only the unresolved source after the
checkpoint:

| Existing Markdown | Prior inline runs | Growth parsed | Growth wall | Closure parsed | Closure wall | Closure append proof |
|---:|---:|---:|---:|---:|---:|:---:|
| 10,070 | 638 | 26 | 0.067 ms | 40 | 0.089 ms | no |
| 100,035 | 6,320 | 26 | 0.663 ms | 40 | 0.735 ms | no |
| 1,000,065 | 63,164 | 26 | 7.903 ms | 40 | 9.008 ms | no |

The parsed-character counts are constant while elapsed time grows almost
exactly with retained inline-run count. On unresolved growth, `_inlineAppend`
walks the complete prefix to recover a one-run suffix proof. On delimiter
closure, that comparison reaches the old final run, correctly rejects an
append, and `DocumentBlock` then recomputes visible-text metrics across the
complete revised tree. Presentation must also treat the closure as a complete
rich replacement.

The next contract needs a parser-owned stable-prefix boundary and an inline
tail replacement carrying both removed and replacement runs. Consumers can
then replace only the range and visual lines owned by that uncertain tail.
This section is the pre-change proof; it does not claim the closure path is
constant yet.

## Parser-owned inline-tail result

`BlockInlineTailReplace` now carries the exact retained-prefix metrics and only
the replacement runs. The incremental parser already owns both values at its
stable checkpoint, so it no longer compares the accumulated inline tree or
recounts visible text to construct the next `DocumentBlock`:

| Existing Markdown | Prior inline runs | Growth parsed | Growth before | Growth after | Closure parsed | Closure before | Closure after |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 10,070 | 638 | 26 | 0.067 ms | 0.013 ms | 40 | 0.089 ms | 0.022 ms |
| 100,035 | 6,320 | 26 | 0.663 ms | 0.013 ms | 40 | 0.735 ms | 0.023 ms |
| 1,000,065 | 63,164 | 26 | 7.903 ms | 0.015 ms | 40 | 9.008 ms | 0.026 ms |

At one million characters, unresolved growth is about 527× faster and closure
about 346× faster. More importantly, both curves are flat while retained runs
grow by two orders of magnitude. This proves parser and block-metric work is
bounded by the unresolved tail. The renderer does not consume the new proof in
this slice, so delimiter closure still schedules a complete rich range and line
replacement there; that is the next measured consumer boundary.

## Viewport-owned inline-tail result

`InlineRangeIndex.replaceTail` binary-seeks the parser's retained-prefix
boundary, shares every earlier persistent leaf, and indexes only replacement
runs. The existing `AppendWrapIndex.replaceTail` then reshapes the visual line
which owns that boundary and the small suffix. No partial range or geometry is
published between them.

| Existing Markdown | Prior inline runs | First retained build | Final indexed | Final build | Mounted after | Scroll delta |
|---:|---:|---:|---:|---:|---:|---:|
| 100,035 | 6,321 | 4.152 ms | 22 | 1.842 ms | 1,650 | 0 px |
| 1,000,065 | 63,165 | 10.756 ms | 22 | 1.584 ms | 1,650 | 0 px |

The same `WindowedRichParagraph` element survives delimiter closure. Indexed
source and mounted styled text are constant, and the parked reader remains
bit-for-bit fixed.

The first retained result still had a size slope, but its cause was not the
flat `String`. The block builder reread all retained inline runs twice: once to
ask whether the paragraph contained inline mathematics and once to recover
footnote controls. The range-safety fact had already proved that neither can
exist. Reusing that fact removes both prefix walks. The one-million-character
build is now below the 100,000-character build, so the remaining difference is
measurement noise rather than positive retained-prefix slope.

An isolated cost ledger prevents the next optimization from being chosen by
intuition:

| Visible characters | Range-tail replacement | Flat-source hash | Direction |
|---:|---:|---:|---:|
| 69,513 | 0.019 ms | 0.075 ms | <0.001 ms |
| 694,797 | 0.218 ms | 0.806 ms | <0.001 ms |

The flat source still has a linear allocation and first-hash cost, but neither
accounts for the former 10.756 ms build. Chunk-addressable source remains a
real total-allocation improvement; it is no longer the next frame-time alarm.

## Sustained million-character stream result

**Problem.** One bounded delimiter replacement does not prove a live answer can
stay bounded. The parser originally retained its old uncertain-tail checkpoint
when one batch closed a delimiter and a later batch opened the next one. The
work stayed independent of the million-character prefix, but grew from 263 to
513 indexed characters over successive cycles. A long answer would therefore
accumulate a second, smaller linear tail.

**Solution.** The checkpoint scanner now promotes the last internally settled
whitespace boundary even when later source remains unresolved. It parses and
publishes that unresolved remainder separately, so live text never disappears,
and checks every incremental result against the canonical full Markdown parse.
Resolved inline structure becomes retained prefix before the next delimiter can
extend the uncertainty window.

The native harness starts with one 1,000,000-character style-dense paragraph,
parks the reader in its middle, opens a real scrollbar interaction epoch, and
publishes 60 revisions. Each of 20 cycles grows an unfinished strong run,
closes it, then opens the next. The visible source grows by 510 characters.

| Measurement | Result |
|---|---:|
| Published revisions | 60 |
| Tail replacements | 60 |
| Parsed source worst | 42 characters |
| Range/wrap indexed worst | 90 characters |
| Build p50 / p90 / p99 / worst | 1.468 / 1.727 / 1.857 / 1.902 ms |
| Total frame p90 / p99 / worst | 3.477 / 4.715 / 4.792 ms |
| Mounted text after stream | 1,716 characters |
| Reader scroll delta | 0 px |
| Scrollbar thumb top delta | 0 px |
| Scrollbar thumb height delta | 0 px |

The roughly 25 ms per-revision harness wall includes two deliberately pumped
frames and an 8 ms simulated-time step; it is not application latency. Native
`FrameTiming` is the rendering distribution. The process RSS snapshot fell by
12.3 MiB during this run, which proves no leak by itself; allocator timing can
move either direction. A long-running heap and GC plateau is the next memory
proof.

This is the stopping point for paragraph frame work. Parser, block facts,
range/style indexing, line geometry, presentation queries, mounted text,
reader position, and visible scrollbar geometry are all bounded by the local
revision in the sustained fixture. Further work here needs a new measured
failure, not a desire to make already sub-5 ms frames look cleverer.
