# Desktop Source Change Monitor

## Purpose and boundary

`DesktopSourceChangeMonitor` implements the application's invalidation port
with native filesystem event streams. It watches directories rather than every
document, so the number of operating-system watches follows the number of open
sources rather than the number of Markdown files
(`lib/infrastructure/io/desktop_source_change_monitor.dart`).

It reports what may have changed. It never reads document content and never
mutates a Library.

## Present wiring

A local directory uses one recursive watch on macOS and Windows. A standalone
Markdown watches its parent and filters events to the exact path. Loose files
are grouped by parent directory and mapped back to their shelf-relative names
(`lib/infrastructure/io/desktop_source_change_monitor.dart`).

File events become targeted `FolderDocumentsInvalidated` values after the same
Markdown and hidden-folder filters used by scanning. Directory events request a
full root rescan because an operating system may coalesce an entire subtree into
one directory signal (`lib/infrastructure/io/desktop_source_change_monitor.dart`).

The desktop platform adapter shares one registry between the scanner and the
monitor, so an opaque `FolderRef` resolves to the same native source in both
capabilities (`lib/infrastructure/platform/platform_io.dart`).

## Inputs and outputs

In: `FolderRef` or `MarkdownRef` already owned by the reader. Out: a stream of
targeted invalidations, a full-rescan request, or `SourceWatchFailed`.

Move events contribute both their origin and destination. Paths are normalized
to portable separators and compared case-insensitively on Windows
(`lib/infrastructure/io/desktop_source_change_monitor.dart`).

## Events

Native create, modify, move and delete events are reduced to the application
vocabulary. No raw `FileSystemEvent`, absolute path, or security bookmark
crosses the infrastructure boundary.

## Lifecycle

Listening opens the native watches. Cancelling the stream cancels every
subscription and stops any fallback timer
(`lib/infrastructure/io/desktop_source_change_monitor.dart`,
`lib/infrastructure/io/desktop_source_change_monitor.dart`). On macOS, security-scoped bookmarks are held for the lifetime of
the watch and released in `dispose`, allowing changes to remain observable
inside the sandbox (`lib/infrastructure/io/desktop_source_change_monitor.dart`,
`lib/infrastructure/io/desktop_source_change_monitor.dart`).

## Failure and recovery

If native watching is unsupported, throws, reports an error, or closes, the
adapter emits one visible failure and starts a five-second fallback invalidation.
Ordinary operation performs no polling while the filesystem is quiet
(`lib/infrastructure/io/desktop_source_change_monitor.dart`).

The adapter test changes a real temporary Markdown file and waits for the native
relative-path event (`test/infrastructure/desktop_source_change_monitor_test.dart`).
Windows uses the same Dart implementation, but native Windows verification is
still required before release.

## Transition

None planned. Platform-specific improvements belong behind this port as long as
they retain directory-level ownership, fresh reads in the application, and the
visible fallback contract.
