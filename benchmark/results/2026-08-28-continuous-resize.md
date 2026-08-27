# Continuous resize geometry baseline

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
