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
settle, and verifies that Flutter's resulting `RenderParagraph` contains every
authored source character.

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
