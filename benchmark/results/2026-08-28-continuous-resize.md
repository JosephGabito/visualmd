# Continuous resize geometry baseline

## Reader's summary

**Problem.** Resizing the window rebuilt one offscreen height estimate per
document block on every width change. Six resize steps over 5,000 blocks
visited 30,000 extents even though only nine paragraphs were retained.

**Solution.** `StableExtentLedger.scaleRelayout` changes one latent scale for
the coordinate system; mounted blocks replace their own estimates as real
measurements arrive.

**Before and after.** The 5,000-block journey falls from 30,000 offscreen extent
visits to zero. Wall time remains effectively flat—51.9 ms before and 51.0 ms
after—but the structural count proves corpus-length work has left the resize
frame.

## Environment

- Flutter 3.47.1 stable, Dart 3.13.1
- macOS 26.5.2, Apple silicon
- profile build
- production `ReadingPane` and quiet viewport geometry adapter
- uniform wrapping paragraphs
- command and metric definitions: `benchmark/README.md`

## Journey

After the first readable frame, the viewport alternates across six widths from
720 to 980 logical pixels. A counting wrapper around the production geometry
adapter records every estimated block extent consumed by a relayout. Fixture
construction and initial geometry are excluded.

## Result

| Blocks | Resize steps | Relayout calls | Extents visited | Visible paragraphs | Retained paragraphs | Wall time |
|---:|---:|---:|---:|---:|---:|---:|
| 100 | 6 | 6 | 600 | 7 | 9 | 50.5 ms |
| 1,000 | 6 | 6 | 6,000 | 7 | 9 | 50.9 ms |
| 5,000 | 6 | 6 | 30,000 | 7 | 9 | 51.9 ms |

RSS deltas were 1.2, 0.8, and 9.5 MiB and are allocator-sensitive. Mounted and
retained widgets remain viewport-bounded; the length dependency is entirely in
the geometry invalidation path.

## What this proves

Every width frame synchronously regenerates and installs one estimate per
document block. The structural count is exactly `blocks × resize steps` even
though this corpus keeps absolute wall time low on the development machine.
The renderer already mounts a constant number of paragraphs, so rebuilding the
offscreen estimate vector is work with no effect on the current pixels.

The next geometry epoch must accept current extents in constant time, invalidate
their measurement revision, and let mounted blocks correct themselves. Any
later offscreen refinement must be bounded or scheduled outside the interactive
resize frame; it cannot restore a corpus-length loop to layout.

## Lazy-scale comparison

`StableExtentLedger.scaleRelayout` now applies one latent scale to the complete
coordinate system and returns the corresponding anchor correction. It does not
iterate the stored extents. Mounted blocks replace their provisional values
with real measurements under the new revision.

| Blocks | Resize steps | Relayout calls | Extents visited | Visible paragraphs | Retained paragraphs | Wall time |
|---:|---:|---:|---:|---:|---:|---:|
| 100 | 6 | 6 | 0 | 7 | 9 | 50.3 ms |
| 1,000 | 6 | 6 | 0 | 7 | 9 | 45.6 ms |
| 5,000 | 6 | 6 | 0 | 7 | 9 | 51.0 ms |

The structural curve falls from 600/6,000/30,000 extent visits to zero. The
5,000-block journey differs from the 100-block journey by 0.7 ms; the middle
run is faster, which shows why structural counts are the stronger proof here.
RSS deltas were 0.9, 2.2, and -7.0 MiB and remain allocator-sensitive.

The package tests prove scale, prefix, offset lookup, append, measurement,
revision fencing, and reverse scaling compose correctly. The Flutter render
test proves a distant anchor keeps its viewport coordinate as its extent scale
doubles. The benchmark now fails if a resize consumes any offscreen extent.
