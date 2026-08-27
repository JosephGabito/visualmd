# Atomic code-line baseline

## Environment

- Flutter 3.47.1 stable, Dart 3.13.1
- macOS 26.5.2, Apple silicon
- profile build, 1280 × 820 logical-pixel viewport
- one unwrapped Dart source line inside the production `ReadingPane`
- multiline source windowing enabled; horizontal column windowing absent

## Result

| Source characters | Characters mounted | Worst frame | RSS added | Horizontal extent |
|---:|---:|---:|---:|---:|
| 10,000 | 10,000 | 5.6 ms | 4.1 MiB | 92,598 px |
| 100,000 | 100,000 | 27.4 ms | 35.1 MiB | 933,174 px |
| 1,000,000 | 1,000,000 | 147.7 ms | 291.3 MiB | 9,338,841 px |

The vertical window correctly mounts one row, but that row is still one
complete `RenderParagraph`. Both retained memory and synchronous frame time
therefore grow with the authored line rather than with the horizontal viewport.

## What this proves

- Line-count virtualization and character-count virtualization are independent
  requirements.
- A generated payload without newlines can still create a visible stall and a
  large retained paragraph after multiline fences have been fixed.
- The complete horizontal extent is already predictable from the monospace
  advance and source length. The renderer can preserve that coordinate system
  while composing only columns near the local horizontal viewport.

## Acceptance boundary

The replacement must keep rendered characters bounded at all three sizes,
retain the complete horizontal scroll range, seek directly into the million-
character line, and leave whole-block copy exact. It must not insert wrapping,
truncate source, or alter the outer document's vertical physics.
