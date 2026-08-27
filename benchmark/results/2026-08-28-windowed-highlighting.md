# Windowed syntax-highlighting result

## Environment

- Flutter 3.47.1 stable, Dart 3.13.1
- macOS 26.5.2, Apple silicon
- profile build, 1280 × 820 logical-pixel viewport
- production `ReadingPane`, two-dimensional code window and warmed
  `ShikiCodeHighlighter`

## Result

| Source characters | Requests | Largest request | Classification total | Tokens returned | RSS delta |
|---:|---:|---:|---:|---:|---:|
| 10,000 | 1 | 10,000 | 34.0 ms | 2,000 | 13.4 MiB |
| 100,000 | 3 | 1,379 | 15.0 ms | 828 | 3.8 MiB |
| 1,000,000 | 3 | 1,379 | 2.0 ms | 828 | 2.8 MiB |

The small document intentionally remains on the complete-source path. At and
above the 32,768-character threshold, classification input and returned token
count become functions of the mounted viewport rather than the fence length.
The one-million-character baseline took 2.93 seconds, retained 200,000 tokens
and added about 123.6 MiB RSS.

`pumpAndSettle` advances the 48 ms debounce through intermediate test-clock
layout states, so this harness records up to three bounded requests while the
window converges. In a real continuous scroll, each position change restarts
the timer. Request revision fencing prevents an earlier source or viewport
result from painting after the current one either way.

## What this proves

- No contributed grammar receives a complete large fence from the renderer.
- Plain source paints before syntax work and scrolling never awaits colour.
- Classification input is capped by visible rows, visible columns and fixed
  overscan; the 100,000- and 1,000,000-character fixtures have the same maximum
  request and token count.
- Window-relative tokens are mapped back into exact document source offsets,
  preserving independent search backgrounds and syntax foregrounds.
- Late results are rejected by a window revision, and rapid movement is
  coalesced by the debounce rather than launching work at pointer frequency.

## Remaining boundary

Window classification begins with bounded overscan, not the complete lexical
state before the viewport. A multiline string or comment opened much earlier
may therefore paint plain or with local-context syntax until a future stateful
grammar session can checkpoint lexical state. Source fidelity is unaffected:
syntax remains an optional foreground enhancement and whole-block copy still
uses the exact model.
