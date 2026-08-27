# Desktop library-scan baseline

## Environment

- Flutter 3.47.1 stable, Dart 3.13.1
- macOS 26.5.2, Apple silicon
- profile build
- real local directories and the production `LocalFolderScanner`
- about 1,096 source bytes per Markdown document
- command and metric definitions: `benchmark/README.md`

## Journey

The harness creates 100, 1,000, and 5,000 Markdown files across folders of 100
documents each. Fixture creation is outside the timed region. The scan includes
directory listing, opening every Markdown file, reading all bytes, UTF-8
decoding, heading-title extraction, and physical source identity construction.

## Result

| Documents | Source bytes | Indexed titles | Elapsed | RSS added |
|---:|---:|---:|---:|---:|
| 100 | 109,490 | 100 | 9.9 ms | 0.48 MiB |
| 1,000 | 1,095,890 | 1,000 | 98.0 ms | 0.88 MiB |
| 5,000 | 5,483,890 | 5,000 | 506.2 ms | 0.58 MiB |

RSS deltas are allocator-sensitive process snapshots, not heap attribution.
Their flat shape agrees with the scanner releasing each source after extracting
its title. Wall time, however, grows almost exactly with document count.

## What this proves

- A desktop library cannot appear until every Markdown file has been opened,
  decoded, and inspected for a title.
- The current scan is serial; one slow file delays every document behind it.
- Source retention is not the problem. Time-to-first-shelf is the problem.
- Larger individual documents make this path grow with total source bytes too,
  even though title discovery usually needs only the leading portion.

## Acceptance boundary

The first repair should bound concurrent metadata reads without changing which
files are admitted, their source identities, or their extracted titles. That
reduces serialized I/O latency but still waits for all titles. A later slice
must separate metadata discovery from deferred title enrichment so the shelf
can appear before the contents of every book have been read.

## Bounded-read comparison

After directory discovery was separated from an eight-worker title-read pool,
the same profile fixture produced:

| Documents | Before | Bounded reads | Improvement | Indexed titles |
|---:|---:|---:|---:|---:|
| 100 | 9.9 ms | 7.0 ms | 29% | 100 |
| 1,000 | 98.0 ms | 58.8 ms | 40% | 1,000 |
| 5,000 | 506.2 ms | 289.6 ms | 43% | 5,000 |

The pool preserves discovery order and caps open work at eight operations. It
removes much of the serialized small-file latency without weakening title or
identity semantics. The remaining 289.6 ms is still paid before the first
shelf snapshot, which confirms the next boundary: discovery and title
enrichment must become separate publications rather than a larger IO pool.
