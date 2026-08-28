# Revisioned append scaling result

## Reader's summary

**Problem.** Appending one generated block must not rescan every already parsed
block or disrupt an unrelated ballistic scroll.

**Solution.** The domain publishes an explicit suffix mutation. Navigation and
render indexes extend from that payload, and stable block keys preserve mounted
elements.

**Measured result.** With 5,000 committed paragraphs, an append visits one
navigation record and one render record, mounts ten paragraphs, and costs a
2.5 ms worst frame. A second append during ballistic scrolling again visits one
record per index while the viewport advances 1,294 px. This is a structural
scaling proof; no pre-change wall-clock baseline was retained in this note.

## Environment

- Flutter 3.47.1 stable, Dart 3.13.1
- macOS 26.5.2, Apple silicon
- profile build, 1280 × 820 logical-pixel viewport
- already-parsed, revisioned block sequence
- command and metric definitions: `benchmark/README.md`

## Result

The initial snapshot necessarily indexes its complete already-parsed model.
Appending one provisional paragraph then visits exactly one record in both the
navigation index and renderer index, regardless of whether the committed prefix
contains 100, 1,000, or 5,000 paragraphs.

| Paragraphs | Initial navigation visits | Append visits | Initial render visits | Append visits | Worst append frame |
|---:|---:|---:|---:|---:|---:|
| 100 | 101 | 1 | 101 | 1 | 2.6 ms |
| 1,000 | 1,001 | 1 | 1,001 | 1 | 2.9 ms |
| 5,000 | 5,001 | 1 | 5,001 | 1 | 2.5 ms |

The heading accounts for the extra initial record. Mounted paragraphs remained
8, 10, and 10 respectively. The append frame stayed far below one 60 Hz frame;
the 5,000-paragraph run was 0.1 ms faster than the 100-paragraph run in this
sample.

The same run injected a second one-block append during a real ballistic scroll.
Every size moved 1,294 logical pixels and visited exactly one additional record
in each index.

| Paragraphs | Concurrent-scroll p90 frame | Concurrent-scroll worst frame |
|---:|---:|---:|
| 100 | 2.7 ms | 4.0 ms |
| 1,000 | 2.7 ms | 3.5 ms |
| 5,000 | 2.7 ms | 3.9 ms |

## What this proves

- The domain can identify a direct revision-to-revision append without scanning
  or comparing the committed prefix.
- The reading pane extends its offset, anchor, and heading indexes from the
  mutation payload.
- The sliver renderer extends its visible-block index from the same payload and
  preserves mounted element identity with stable block keys.
- A reader positioned above the tail keeps the same physical scroll offset in
  the widget regression test.

## Remaining boundary

The immutable snapshot currently copies its block-record list when applying a
mutation. The source is also still represented as one complete string and the
Markdown adapter remains a whole-document parser. Those costs sit before this
measured presentation path and are the next streaming layers.

Quiet Viewport's framework-independent extent ledger and frozen-scrollbar math
are proven in its package tests. Visual MD's custom sliver now seeks from the
ledger, measures only its cache window, and applies Flutter's native pre-paint
scroll correction when geometry changes above the active block. Widget proofs
cover a 5,000-item far seek without building its prefix, a whole layout-epoch
change, a revised block above the reader, and a frozen thumb absorbing the same
physical correction without moving. The remaining whole-document costs are the
source string, one-shot parser, and immutable block snapshot described above.
