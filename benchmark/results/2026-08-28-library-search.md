# Library-search refinement baseline

## Environment

- Flutter 3.47.1 stable, Dart 3.13.1
- macOS 26.5.2, Apple silicon
- profile build
- production `SearchDocuments`, Markdown parser, and literal visible-text search
- deterministic source adapter; 1,328 source characters per document
- command and metric definitions: `benchmark/README.md`

## Journey

The benchmark searches 100, 1,000, and 5,000 unchanged Markdown documents.
It issues three successive refinements: `needle`, `needle 7`, and `needle 77`.
The source adapter is deterministic so filesystem variance cannot obscure the
work performed by the application and parser. Structural counters record every
source request and complete Markdown parse.

## Result

| Documents | Query | Matches | Source reads | Parses | Elapsed |
|---:|---|---:|---:|---:|---:|
| 100 | `needle` | 100 | 100 | 100 | 53.9 ms |
| 100 | `needle 7` | 11 | 100 | 100 | 51.6 ms |
| 100 | `needle 77` | 1 | 100 | 100 | 51.2 ms |
| 1,000 | `needle` | 1,000 | 1,000 | 1,000 | 518.2 ms |
| 1,000 | `needle 7` | 111 | 1,000 | 1,000 | 515.8 ms |
| 1,000 | `needle 77` | 11 | 1,000 | 1,000 | 514.4 ms |
| 5,000 | `needle` | 5,000 | 5,000 | 5,000 | 2,555.0 ms |
| 5,000 | `needle 7` | 111 | 5,000 | 5,000 | 2,541.1 ms |
| 5,000 | `needle 77` | 11 | 5,000 | 5,000 | 2,551.6 ms |

## What this proves

- Query refinement repeats source I/O and full Markdown parsing for every
  unchanged document.
- Work is proportional to total library source, not to changed source or the
  shrinking match set.
- Cancellation between documents prevents a stale result from winning, but it
  does not make the current query cheap.
- A 5,000-document refinement already takes roughly 2.55 seconds before real
  filesystem latency is added. Streaming would compete with that work.

## Acceptance boundary

An unchanged library may pay once to construct its visible-text projections.
Later query refinements must perform zero source reads and zero Markdown parses.
Source invalidation must evict only the changed document, removing a document
must release its projection, and retained projections must have a byte budget.
Matching the query against every projection remains proportional to library
text; removing that final scan requires a token or n-gram index and is a later
measurement, not something this baseline pretends to solve.
