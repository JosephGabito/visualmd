# ReadDocument

## Purpose and boundary

`ReadDocument` turns a `DocumentId` into a `DocumentReading`: the document, the
outline to navigate it by, and the blocks to set on the page
(`lib/application/use_cases/read_document.dart:38-60`). It reads from the
current library only; it never scans and never renders. It does not parse
either — it *asks*, through the
[Document Parser port](04-document-parser-port.md), and the outline comes from
the domain ([Document Outline](../01-domain/03-document-outline.md)).
Rendering belongs to the [reading pane](../05-api/04-reading-pane.md).

## Present wiring

`execute(id)` (`lib/application/use_cases/read_document.dart:49-59`):

1. `_repository.current()` — the open `Library`, or `null`.
2. `library.find(id)` — the document, or `null`
   (`lib/domain/library/library.dart:18`).
3. Return a `DocumentReading` of three things
   (`lib/application/use_cases/read_document.dart:54-58`): the document; its
   outline, which is the document's cached, lazily parsed one
   (`lib/domain/library/document.dart:22`); and its content, parsed here
   through the injected port.

The outline and the content are parsed separately, by different code, from the
same source. They agree because both take their heading anchors from one rule,
`HeadingAnchors` (`lib/domain/reading/heading_anchor.dart:7-29`) — which is
what makes a link found in the outline resolve on the page. The use-case test
asserts exactly that
(`test/application/use_cases_test.dart:62-67`).

`ReaderController.addFolder` reads the document selected by the folder mutation
(`lib/api/reader_controller.dart:158-180`). `ReaderController.openDocument`
does the same for a shelf selection and skips the work when that document is
already open (`lib/api/reader_controller.dart:396-403`).

## Inputs and outputs

| | Type | Notes |
|---|------|-------|
| Input | `DocumentId` | Already normalised; see [Library aggregate](../01-domain/01-library-aggregate.md). |
| Output | `DocumentReading` | `document`, `outline` (`tableOfContents`, `sections`, `frontMatter`) and `content` (`lib/application/use_cases/read_document.dart:11-21`). |

The parser arrives as a constructor dependency
(`lib/application/use_cases/read_document.dart:39-47`), so the use case can be
tested against any implementation and knows nothing about markdown.

## Events

None today. The [Plugin Architecture](../07-roadmap/01-plugin-architecture.md)
describes a possible `DocumentOpened` event for features such as recent
documents. That event is roadmap direction, not part of the current use case.

## Lifecycle

Stateless and `const`. The outline is cached on the `Document`; content is
parsed afresh on every read. Keeping parsed content in the returned
`DocumentReading` avoids shared mutable parsing state. The current parser is
synchronous, so any future performance change should begin with measurements
on representative large documents.

## Failure and recovery

| Condition | Thrown | Defined at | Tested at |
|-----------|--------|------------|-----------|
| No library has been opened | `NoLibraryOpen` | `lib/application/use_cases/read_document.dart:23-28`, thrown at `:51` | `test/application/use_cases_test.dart:70-73` |
| Id not in the library | `DocumentNotFound(id)` | `lib/application/use_cases/read_document.dart:30-36`, thrown at `:53` | `test/application/use_cases_test.dart:75-76` |

Parsing adds no third failure: the port's contract is that it does not throw
([Document Parser Port](04-document-parser-port.md)).

The controller does not catch these today: the shelf only offers ids that
exist, and the welcome view is shown until a library opens, so neither can be
reached through the UI. A stale link resolved by
`ReaderController.resolveLink` is checked against `library.find` before the
use case is called (`lib/api/reader_controller.dart:412-434`), so a missing id
indicates stale caller state rather than a document the interface knowingly
offered.

The happy path — title, headings, and the outline agreeing with the page — is
`test/application/use_cases_test.dart:55-68`.

## Transition

An opened-document event can be added when a real subscriber needs it. A
reading-position feature would first need a domain concept for the saved
position rather than treating it as an untyped plugin value; see
[0007 — Plugins as Typed Hooks](../08-decisions/0007-plugins-as-typed-hooks.md).
