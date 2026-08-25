# ReadDocument

## Purpose and boundary

`ReadDocument` turns a `DocumentId` into a `DocumentReading`: a transient
source-backed document, the outline to navigate it by, and the blocks to set
on the page
(`lib/application/use_cases/read_document.dart`). It reads from the
current library and obtains that one document's source through
`DocumentSourceReader` (`lib/application/document_source_reader.dart`). It
never renders. It asks the [Document Parser port](04-document-parser-port.md)
for blocks, and the outline comes from the domain
([Document Outline](../01-domain/03-document-outline.md)).
Rendering belongs to the [reading pane](../05-api/04-reading-pane.md).

## Present wiring

`execute(id)` (`lib/application/use_cases/read_document.dart`):

1. `_repository.current()` — the open `Library`, or `null`.
2. `library.find(id)` — the document, or `null`
   (`lib/domain/library/library.dart`).
3. Return an existing cached reading and promote it to most recently used, or
   join an in-flight read for the same id.
4. Otherwise `DocumentSourceReader` routes the source request to the folder or
   standalone scanner port (`lib/application/document_source_reader.dart`).
5. Build one source-backed `Document`, derive its outline, parse its blocks,
   and retain the complete `DocumentReading` as the newest cache entry
   (`lib/application/use_cases/read_document.dart`).

The outline and blocks are parsed separately, by different code, from the same
transient source. They agree because both take their heading anchors from one rule,
`HeadingAnchors` (`lib/domain/reading/heading_anchor.dart`) — which is
what makes a link found in the outline resolve on the page. The use-case test
asserts exactly that
(`test/application/use_cases_test.dart`).

`ReaderController.addFolder` reads the document selected by the folder mutation
(`lib/api/reader_controller.dart`). `ReaderController.openDocument`
does the same for a shelf selection and skips the work when that document is
already open (`lib/api/reader_controller.dart`).

## Inputs and outputs

| | Type | Notes |
|---|------|-------|
| Input | `DocumentId` | Already normalised; see [Library aggregate](../01-domain/01-library-aggregate.md). |
| Output | `DocumentReading` | source-backed `document`, exact `source`, `outline` (`tableOfContents`, `sections`, `frontMatter`) and parsed `content` (`lib/application/use_cases/read_document.dart`). |

The parser and source reader arrive as constructor dependencies
(`lib/application/use_cases/read_document.dart`). Scanner routing stays in the
application service and platform access stays behind ports, so the use case
knows neither Markdown parsing details nor file and browser APIs.

## Events

None today. The [Plugin Architecture](../07-roadmap/01-plugin-architecture.md)
describes a possible `DocumentOpened` event for features such as recent
documents. That event is roadmap direction, not part of the current use case.

## Lifecycle

One stateful instance lives for the reader session. Its access-ordered cache
holds at most ten complete readings. A hit removes and reinserts the entry,
making the least recently used reading the next eviction candidate. Concurrent
opens of one id share one in-flight source read and parse
(`lib/application/use_cases/read_document.dart`).

The controller invalidates changed sources, releases readings removed from the
library, and clears the cache when a workspace is replaced or the controller
is disposed (`lib/api/reader_controller.dart`). An invalidated in-flight read
may still satisfy its original caller, but a generation check prevents it from
putting stale source back into the cache. These lifecycle invariants are pinned
by `test/application/read_document_cache_test.dart`.

## Failure and recovery

| Condition | Thrown | Defined at | Tested at |
|-----------|--------|------------|-----------|
| No library has been opened | `NoLibraryOpen` | `lib/application/use_cases/read_document.dart`, thrown at `lib/application/use_cases/read_document.dart` | `test/application/use_cases_test.dart` |
| Id not in the library | `DocumentNotFound(id)` | `lib/application/use_cases/read_document.dart`, thrown at `lib/application/use_cases/read_document.dart` | `test/application/use_cases_test.dart` |
| The retained platform source cannot supply the document | `DocumentSourceUnavailable(document)` | `lib/application/document_source_reader.dart` | `test/application/read_document_cache_test.dart` |

Parsing adds no further failure: the port's contract is that it does not throw
([Document Parser Port](04-document-parser-port.md)). Source access may still
surface its platform error when permission is revoked or a file disappears.

The controller does not catch these today: the shelf only offers ids that
exist, and the welcome view is shown until a library opens, so neither can be
reached through the UI. A stale link resolved by
`ReaderController.resolveLink` is checked against `library.find` before the
use case is called (`lib/api/reader_controller.dart`), so a missing id
indicates stale caller state rather than a document the interface knowingly
offered.

The happy path — title, headings, and the outline agreeing with the page — is
`test/application/use_cases_test.dart`; cache order, concurrency and
invalidation are `test/application/read_document_cache_test.dart`.

## Transition

An opened-document event can be added when a real subscriber needs it. A
reading-position feature would first need a domain concept for the saved
position rather than treating it as an untyped plugin value; see
[0007 — Plugins as Typed Hooks](../08-decisions/0007-plugins-as-typed-hooks.md).
