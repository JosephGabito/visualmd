# Generated Markdown stream baseline

## Environment

- Flutter 3.47.1 stable, Dart 3.13.1
- macOS 26.5.2, Apple silicon
- profile build, 1280 × 820 logical-pixel viewport
- real `GeneratedDocumentStreamSession`, incremental Markdown parser,
  revisioned document model, `ReadingPane`, and Quiet Viewport geometry
- command and metric definitions: `benchmark/README.md`

## Journey

The session first accepted and committed 5,000 ordinary Markdown paragraphs.
While the reader was in a ballistic scroll, it then accepted 60 source deltas
forming 20 more paragraphs. Each paragraph arrived in three publications: an
opening provisional fragment, a continuation which replaced that provisional
block, and a blank-line boundary which committed it.

This is the hot path a generated answer will use:

```text
ordered source delta
→ chunked source retention
→ incremental Markdown parse
→ persistent document suffix mutation
→ navigation and renderer suffix indexes
→ retained viewport geometry
→ Flutter build, layout, and paint
```

## Result

| Measurement | Profile result |
|---|---:|
| Committed prefix | 5,000 blocks |
| Published revisions | 60 |
| Largest parsed suffix | 124 characters |
| Parse, outline, and publish p50 | 0.186 ms |
| Parse, outline, and publish p90 | 0.262 ms |
| Parse, outline, and publish worst | 0.342 ms |
| Outline blocks visited per revision | 1 |
| Navigation records visited per revision | 1 |
| Renderer records visited per revision | 1 |
| Mounted paragraphs after the journey | 11 |
| Frame total p90 | 2.290 ms |
| Frame total worst | 2.870 ms |
| Ballistic scroll progress | 2,609 logical pixels |

The 60 parse sizes repeated the expected bounded pattern: 59–60 characters for
the opening fragment, 121–122 after its continuation, and 123–124 when the
blank line committed it. None included any character from the 5,000-block
prefix.

The benchmark also records a harness revision wall time around 25 ms. That is
not application latency: the harness deliberately advances two frames for each
publication, including an 8 ms simulated-time step. Synchronous source accept,
parse, mutation, outline projection, and publication are the
0.186/0.262/0.342 ms distribution; Flutter frame timings independently report
the rendering cost.

## What this proves

- Normal generated prose does not reparse its committed source prefix.
- A provisional paragraph can change repeatedly without copying the committed
  block model or rebuilding derived reader indexes.
- The live table of contents projects the same suffix mutation and preserves
  immutable prior revisions without rescanning committed headings.
- The geometry ledger retains measured prefix extents while its suffix changes.
- Widget, element, layout, paint, and semantics work remains proportional to
  the viewport; 5,020 paragraphs leave only 11 mounted.
- Streaming updates do not cancel or pin an unrelated ballistic scroll.

This does **not** claim that constructing the initial 5,000-block snapshot is
constant time; it took 219 ms in this run and is necessarily proportional to
the source being opened. The result proves that later update cost is independent
of that committed prefix for this grammar path.

## Remaining boundary

Live outline headings omit exact source lines and source-sliced sections; the
reader does not consume either. Rare late global link or footnote definitions
also trigger a documented semantic rebase because they can change earlier
blocks. That exceptional dependency cost should eventually be indexed; it must
not be disguised as constant work.

The next performance experiment should compare the same delta sizes over
100, 1,000, and 5,000 committed blocks in one run. The structural counters
already prove prefix independence; the scaling run will quantify whether cache,
GC, or scheduler effects introduce a practical slope the algorithm does not.
