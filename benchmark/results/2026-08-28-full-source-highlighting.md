# Full-source syntax-highlighting baseline

## Reader's summary

**Problem.** Viewport-bounded code layout still sent the complete fence through
syntax classification. One million characters took 2.93 seconds, returned
200,000 tokens, and added 123.6 MiB of process RSS.

**Solution.** The paired
[windowed-highlighting result](2026-08-28-windowed-highlighting.md) debounces and
revision-fences classification requests for only the mounted source window;
plain source paints without waiting for colour.

**Before and after.** At one million characters, classification input falls
from 1,000,000 characters to a largest request of 1,379, returned tokens fall
from 200,000 to 828, and measured classification time falls from 2,930.9 ms to
2.0 ms.

## Environment

- Flutter 3.47.1 stable, Dart 3.13.1
- macOS 26.5.2, Apple silicon
- profile build
- production `ShikiCodeHighlighter`, warmed Dart grammar and dark scheme
- generated 30-character Dart lines; no overlong-line fallback

## Result

| Source characters | Elapsed | Tokens retained | RSS added |
|---:|---:|---:|---:|
| 10,000 | 1.47 ms | 2,000 | 0.5 MiB |
| 100,000 | 267.8 ms | 20,000 | 17.7 MiB |
| 1,000,000 | 2,930.9 ms | 200,000 | 123.6 MiB |

This benchmark calls the shipped adapter directly after warming its language
and theme. The measured slope is classification and result retention, not
Flutter widget construction or a cold grammar decode.

Shiki already gives an overlong individual line one plain token after 20,000
characters. That safety valve does not help a large multiline fence whose
ordinary lines each remain below the per-line limit, so the production path
still tokenizes and retains the complete block.

## What this proves

- Making layout viewport-bounded does not make the enhancement pipeline
  viewport-bounded.
- Reclassifying a growing provisional fence from its beginning would consume
  seconds per publication at this size.
- The reader must keep plain source immediately available, debounce viewport
  classification, reject stale windows, and retain only tokens that can affect
  the mounted source window.

## Acceptance boundary

For a large fence, no request to a contributed `CodeHighlighter` may contain
the complete source. The visible-window request must remain under a fixed
character budget, late results must not cross source or viewport revisions,
and scrolling must never wait for syntax colour. Ordinary small blocks keep
the existing complete-source contract and fidelity.
