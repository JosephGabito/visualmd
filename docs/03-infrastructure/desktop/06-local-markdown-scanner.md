# Local Markdown Scanner

## Purpose and boundary

`LocalMarkdownScanner` implements `MarkdownScanner` for one directly dropped
local file. It reads bytes and reports opaque physical identity; it does not
decide whether the document is new or already inside a folder
(`lib/infrastructure/io/local_markdown_scanner.dart`).

## Present wiring

`DesktopFolderDrop` classifies exactly one non-directory markdown before its
ordinary folder conversion. It registers `LocalMarkdown(path, bookmark)` and
emits `MarkdownRef`; directories and multi-file drops retain the folder path
(`lib/infrastructure/io/desktop_folder_drop.dart`).

The scanner looks up that handle, opens its macOS security scope when a
bookmark exists, decodes malformed UTF-8 defensively, and returns the base
name, content and local source identity
(`lib/infrastructure/io/local_markdown_scanner.dart`).

`localMarkdownIdentity` normalizes an absolute path and folds case on Windows,
whose filesystem comparison is case-insensitive. `DocumentSourceId` wraps the
result before it crosses into the domain
(`lib/infrastructure/io/local_markdown.dart`). Directory scans call the
same function for every retained file
(`lib/infrastructure/io/local_folder_scanner.dart`).

## Inputs and outputs

| Input | Output |
|-------|--------|
| one dropped markdown path and optional bookmark | `MarkdownRef` |
| registered `MarkdownRef` | `ScannedMarkdown` with non-null source identity |
| unknown ref | `MarkdownUnavailable` |

## Events

None. The adapter supplies a ref and source content; application use cases own
the library mutation that follows.

## Lifecycle

The desktop platform owns one Markdown registry, scanner and drop adapter for
the process (`lib/infrastructure/platform/platform_io.dart`). Handles
and source identities are session-scoped.

The filesystem test scans one README through its parent directory and directly
and proves both routes produce the same identity
(`test/infrastructure/local_folder_scanner_test.dart`).

## Failure and recovery

An unknown ref becomes `MarkdownUnavailable`. File and security-scope errors
propagate to `AddMarkdown`; no partial document enters the aggregate. A single
non-markdown file follows the legacy loose-file folder path and shelves
nothing rather than being mislabeled as markdown.

## Transition

A durable source id may later be backed by a macOS bookmark rather than a path.
The domain equality contract permits that change without exposing either
representation to the application.
