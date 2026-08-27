# Viewport sliver baseline and result

## Environment

- Flutter 3.47.1 stable, Dart 3.13.1
- macOS 26.5.2, Apple silicon
- profile build, 1280 × 820 logical-pixel viewport
- identical generated, already-parsed corpus before and after the renderer change
- command and metric definitions: `benchmark/README.md`

## Result

The eager page mounted every paragraph. The sliver page mounts only the visible
and cached run. Frame cost now stays approximately flat as the corpus grows by
50 times.

| Blocks | Mounted before | Mounted after | Worst initial frame before | After | Worst append-one frame before | After |
|---:|---:|---:|---:|---:|---:|---:|
| 100 | 100 | 8 | 16.3 ms | 11.5 ms | 8.5 ms | 2.0 ms |
| 1,000 | 1,000 | 11 | 82.0 ms | 1.7 ms | 34.7 ms | 1.8 ms |
| 5,000 | 5,000 | 11 | 296.6 ms | 1.8 ms | 110.0 ms | 3.3 ms |

At 5,000 blocks this is 99.8 percent fewer mounted paragraph widgets, about
167 times less worst-frame work on initial presentation, and about 33 times
less worst-frame work for a one-block source update.

RSS deltas confirmed the eager renderer's growth — the 5,000-block run added
about 247 MB during its journey — but per-row RSS after the refactor is not used
as a precise comparison because the three workloads share one process and the
allocator retains pages between runs. Mounted widgets and frame timings are the
repeatable scaling evidence.

## Remaining boundary

The top-level renderer performs one lightweight linear indexing pass when a new
content list arrives. It no longer builds, lays out, paints, or registers
semantics for that full list. A future streaming content model should make this
index append-aware so the provisional tail costs only the incoming delta.

One huge nested container is still one top-level sliver child. Full-document
select-all also needs an explicit model-backed command because Flutter's stock
selection action sees only registered lazy children. Both are intentionally
separate from this first, measured renderer intervention.
