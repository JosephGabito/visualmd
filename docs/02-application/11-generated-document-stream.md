# Generated Document Stream

## Purpose and boundary

`GeneratedDocumentStreamSession` turns a noisy sequence of generated Markdown
deltas into ordered, lossless document revisions
(`lib/application/generated_document_stream.dart`). It owns protocol validation,
small-batch coalescing, parse cadence, and generation fencing. It does not own a
WebSocket, model SDK, child process, persistence, Markdown grammar, or Flutter
widget.

This separation is the streaming equivalent of the existing scanner ports: a
future transport can change without changing what an accepted source delta
means or how a document revision reaches downstream consumers.

## Present wiring

The session is a proven application kernel and is not yet connected to a
production transport or `ReaderController`. Its parser is supplied through
`IncrementalDocumentParser`; `MarkdownDocumentParser` is the current adapter
(`lib/application/ports/document_parser.dart`,
`lib/infrastructure/markdown/markdown_document_parser.dart`).

Opening a session supplies one `DocumentId` and one `DocumentStreamId`. The
caller then delivers deltas, finish, or failure events. Revisions are published
on a broadcast stream with a live outline derived from the same block mutation,
so presentation and navigation consume one ordered commit instead of inventing
separate refresh paths. Search can attach to that boundary later.

## Inputs and outputs

| Value | Contract |
|-------|----------|
| `GeneratedDocumentDelta` | Exact source, generation ID, monotonically increasing sequence, and the required source offset |
| `GeneratedDocumentFinished` | Final sequence and accepted source length; no hidden suffix is allowed |
| `GeneratedDocumentFailed` | Final sequence and reason; accepted source remains readable, including a provisional tail |
| `GeneratedDocumentRevision` | Highest included sequence, accepted source length, actual parsed character count, outline blocks visited, status, revisioned `DocumentContent`, and its live `DocumentOutline` |

Duplicates are idempotent. An event from another generation is stale and is
ignored. A gap or wrong source offset throws
`GeneratedDocumentProtocolException` before source or parser state changes.

## Events

The session emits one `GeneratedDocumentRevision` per parser commit. Tiny
deltas wait at most 24 milliseconds by default. A Markdown blank-line boundary
publishes immediately, and 4096 queued characters force a batch even when an
author is still producing one large paragraph. These are constructor policies,
not protocol facts; the performance harness can tune them without changing
event meaning (`lib/application/generated_document_stream.dart`).

## Lifecycle

One session owns one generation. Source starts at offset zero and sequence
zero. Pending deltas are joined once per bounded batch, then the incremental
parser decides which blocks can be committed. Finish flushes pending source
without an intermediate UI revision, runs the canonical final parse, publishes
one finished revision, and closes. Failure does the same pending flush but
preserves provisional meaning instead of pretending the document completed.

`cancel()` discards only source which had not yet reached the parser, cancels
the timer, closes revision delivery, and fences every late event. There is no
idle loop: a quiet stream schedules no work.

The outline projection keeps one source-entry checkpoint per block and a
persistent heading sequence. A suffix mutation truncates at its checkpoint and
visits only replacement blocks. Paragraph-only revisions reuse the exact same
outline object; a heading revision structurally shares every committed heading.
Live headings omit source lines and exact sections rather than fabricating
metadata the streaming parser does not retain
(`lib/application/generated_document_stream.dart`,
`lib/domain/collection/persistent_sequence.dart`).

## Failure and recovery

Protocol gaps and offset mismatches are explicit failures because rendering
corrupted source would make retry state unknowable. The transport may recover
by opening a new generation from an authoritative snapshot. Duplicate delivery
needs no recovery. Producer failure preserves the exact accepted prefix and
its current parsed content so the reader does not lose a partial answer.

`test/application/generated_document_stream_test.dart` proves coalescing,
boundary and size flushes, duplicates, gaps, offsets, stale generations,
canonical finish, failure preservation, incremental immutable outline
projection, and a canceled timer which cannot publish late work.

The native profile benchmark repeats the same 60 live revisions over 100,
1,000, and 5,000 committed blocks. Every update visits one parser tail, outline
record, navigation record, and renderer record; the parse/publish and frame
latency distributions show no positive prefix-length slope
(`integration_test/reading_performance_test.dart`,
`benchmark/results/2026-08-28-generated-stream.md`).

## Transition

The synthetic source and chunk-to-frame benchmark now consume the live outline.
If later profiling shows parse work contends with scrolling, this same
synchronous session contract can move behind one persistent worker isolate;
creating one isolate per transport chunk would defeat batching and lifecycle
ownership.
