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

The first run left one practical question open: whether cache, GC, or scheduler
effects introduced a prefix-length slope which the structural counters could
not reveal. The scaling verification below answers it.

## Prefix-scaling verification

The benchmark was then repeated as one native profile journey over 100, 1,000,
and 5,000 committed blocks. Each row published the same 60 revisions while a
ballistic scroll was active. The harness now records p99 as well as p50, p90,
and worst-case latency.

| Committed blocks | Initial parse | Parse/publish p50 | p90 | p99 | worst | Frame p90 | p99 | worst |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 100 | 10.681 ms | 0.155 ms | 0.234 ms | 0.285 ms | 0.295 ms | 2.119 ms | 2.778 ms | 2.929 ms |
| 1,000 | 44.139 ms | 0.108 ms | 0.172 ms | 0.240 ms | 0.273 ms | 1.461 ms | 2.137 ms | 2.603 ms |
| 5,000 | 209.458 ms | 0.104 ms | 0.173 ms | 0.324 ms | 0.335 ms | 1.455 ms | 2.163 ms | 2.385 ms |

Initial parsing grows with source size, which is necessary work. The live
update distributions do not grow with the committed prefix: p90 parse/publish
latency is effectively identical at 1,000 and 5,000 blocks, and the 100-block
run is slower rather than faster. Frame latency shows the same absence of a
positive slope.

Every row parsed at most 121 source characters per publication, visited one
outline record, one navigation record, and one renderer record, retained eight
paragraph widgets, and continued scrolling. RSS deltas were 6.3 MiB,
-0.5 MiB, and 0.1 MiB; those single process snapshots reflect allocator timing
and are not used as memory-slope evidence.

This closes the earlier practical-scaling question for ordinary generated
prose: the measured hot path is independent of the committed prefix on this
machine. It does not close the separate large-atomic-tail or long-running heap
plateau boundaries.
