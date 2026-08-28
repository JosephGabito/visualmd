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
