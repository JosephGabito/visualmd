# Wrapped atomic code-block baseline

## Environment

- Flutter 3.47.1 stable, Dart 3.13.1
- macOS 26.5.2, Apple silicon
- profile build, 1280 × 820 logical-pixel viewport
- production windowed code view followed by **Wrap long lines**
- command and metric definitions: `benchmark/README.md`

## Journey

Each document contains one fenced Dart block whose deliberately long physical
lines wrap at the real reading width. The opening unwrapped view is already
windowed. The timed action presses **Wrap long lines**, waits for layout to
settle, and records how many physical lines and source characters become real
render objects. Exact whole-source copying is verified separately through the
block's model-backed Copy action.

## Result

| Lines | Source characters | Wrap wall time | Worst frame | RSS added | Rendered characters |
|---:|---:|---:|---:|---:|---:|
| 1,000 | 121,669 | 107.6 ms | 28.7 ms | 17.1 MiB | 121,669 |
| 10,000 | 1,246,669 | 200.7 ms | 191.6 ms | 287.8 MiB | 1,246,669 |
| 50,000 | 6,366,669 | 911.2 ms | 896.7 ms | 1,593.2 MiB | 6,366,669 |

RSS is a process delta around sequential replacements, not heap attribution.
The 1.56 GiB increase and nearly 0.9-second frame at 50,000 lines are far above
allocator noise.

## What this proves

- The default unwrapped path is viewport-bounded, but its wrap toggle replaces
  that path with one eager `Text.rich` containing the complete fence.
- The cost grows with total source, not visible wrapped rows.
- This is both a frame-stall and retained-memory failure. It cannot coexist
  safely with a long generated fence.
- Disabling wrapping would avoid the cost but break an explicit reader feature;
  it is not an acceptable repair.

## Acceptance boundary

Wrapped layout must preserve Flutter's actual line breaking, exact type metrics,
search styling, selection, and source copying while mounting only wrapped rows
near the outer document viewport. The outer scroll extent must still represent
the complete wrapped height, and toggling wrap must not move the scrollbar thumb
during an active interaction. Fixed character-count wrapping is not equivalent
to the text engine and does not satisfy this contract.

## Windowed result

The repaired path keeps a dense height ledger for physical source lines. Its
initial estimates establish the complete scrollbar coordinate system, while
Flutter shapes only the mounted lines and replaces their estimates with exact
heights. Syntax classification follows the same mounted source window.

| Lines | Baseline worst frame | Windowed worst frame | Baseline RSS added | Windowed RSS added | Mounted lines | Mounted characters |
|---:|---:|---:|---:|---:|---:|---:|
| 1,000 | 28.7 ms | 7.4 ms | 17.1 MiB | 2.0 MiB | 27 | 3,156 |
| 10,000 | 191.6 ms | 9.4 ms | 287.8 MiB | 1.1 MiB | 27 | 3,156 |
| 50,000 | 896.7 ms | 19.3 ms | 1,593.2 MiB | 3.2 MiB | 27 | 3,156 |

At 50,000 lines this removes about 46 times the worst-frame cost and about 500
times the observed RSS growth. The block still copies all 6,366,669 source
characters exactly because copying reads the model rather than the mounted
render objects.

The initial estimate vector is O(physical lines); it reads line lengths but
does not shape text. Once that coordinate system exists, shaping, layout,
paint, semantics and highlighting are bounded by the visible window plus
overscan. A future streaming line index can make appending to one still-open
fence incremental without weakening this viewport contract.
