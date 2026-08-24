# Application

The domain knows what a valid library is. The application ring turns a user's
intent into a sequence of work: scan a folder, build the library, save the new
state, and return a result the interface can present. These sequences are the
use cases under `lib/application/`.

Whenever a use case needs something from the outside world, it asks through a
small interface called a **port**. `FolderScanner`, `LibraryRepository`, and
`DocumentParser` describe what the use case needs without choosing a filesystem,
browser API, or markdown package. Infrastructure provides those implementations
when the app starts.

This keeps the application focused on orchestration. Domain behaviour remains
in `lib/domain/`, while loading indicators, drag interactions, and selected-row
state remain in the Flutter-facing API ring. [Dependency Direction](../00-foundation/03-dependency-direction.md)
shows how those pieces depend on one another.

## Follow a feature through the ring

Adding a folder is a representative example. `AddFolder` asks a scanner port
for markdown files, gives those files to `LibraryBuilder`, asks the repository
port to save the new library, and returns `AddedFolder`. Each step has one
owner, which makes the same use case straightforward to test with in-memory
ports and to run with either web or desktop adapters.

Reading, searching, standalone markdown, and workspace persistence use the
same pattern. Their component documents explain the sequence and name the ports
involved:

| Document | What you will learn |
|----------|---------------------|
| [Library Mutations](01-library-mutations.md) | How folders are added, refreshed, removed, and rearranged as one complete change. |
| [ReadDocument](02-read-document.md) | How a document identity becomes parsed content and an outline. |
| [Ports](03-ports.md) | The scanner and repository interfaces, plus the adapters that satisfy them. |
| [Document Parser Port](04-document-parser-port.md) | Why markdown parsing sits behind an application-owned interface. |
| [SearchDocuments](05-search-documents.md) | How current-document and whole-library searches are selected and grouped. |
| [Document Search Port](06-document-search-port.md) | The visible-text search capability requested from infrastructure. |
| [AddMarkdown](07-add-markdown.md) | How one dropped markdown opens directly or reconnects with its containing folder. |
| [RemoveMarkdown](08-remove-markdown.md) | How a standalone document leaves the session without losing reading intent. |
| [Workspace Lifecycle](09-workspace-lifecycle.md) | How New, Open, Save, Save As, restore, reconnect, and autosave fit together. |
| [Source Synchronization](10-source-synchronization.md) | How external edits become ordered, atomic Library refreshes without moving the reader. |

## Where to continue

Start with [Library Mutations](01-library-mutations.md) for the clearest complete
use-case flow, then read [Ports](03-ports.md) to see how external work is
requested. [Reader Controller](../05-api/01-reader-controller.md) shows how the
Flutter interface calls these use cases, while [Infrastructure](../03-infrastructure/README.md)
introduces the adapters that answer their ports.

Application tests replace those adapters with small in-memory versions. The
workspace suite also exercises recovery and failure paths—unavailable sources,
standalone-file absorption, Save As identity, browser download fallback, and
autosave errors—so platform implementations can change without weakening the
workflow (`test/application/workspace_use_cases_test.dart`).
