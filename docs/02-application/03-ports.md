# Ports

A port is an interface the application needs, named for the need. The
application owns the contract; infrastructure supplies implementations; the
composition root chooses which (`lib/main.dart:46-110`).

## FolderScanner

Reads the files beneath a folder the reader offered
(`lib/application/ports/folder_scanner.dart:29-32`).

| Member | Type | Contract |
|--------|------|----------|
| `scan(FolderRef ref)` | `Future<ScannedFolder>` | Return every file the adapter can read beneath the ref, or throw `FolderUnavailable`. Adapters may skip files the domain would discard; they must not sort or prune folders. |

### Value types

| Type | Defined at | Meaning |
|------|------------|---------|
| `FolderRef(id, name)` | `lib/application/ports/folder_scanner.dart:5-19` | Opaque handle. Equality and hash by `id` only (`:11-15`). The `name` is what the library will be called. |
| `ScannedFolder(name, files)` | `lib/application/ports/folder_scanner.dart:22-27` | Name plus a flat list of `FileEntry` (`lib/domain/library/library_builder.dart:11-16`). |
| `FolderUnavailable(ref)` | `lib/application/ports/folder_scanner.dart:35-41` | The ref is unknown to this scanner, or the folder is gone. |

### Implementations

| Adapter | Defined at | Recognises | Throws `FolderUnavailable` when |
|---------|------------|------------|---------------------------------|
| `RoutingFolderScanner` | `lib/infrastructure/routing_folder_scanner.dart:5-21` | Whatever any scanner in its list recognises; tries each in order and moves on when one throws `FolderUnavailable` (`:12-17`) | Every scanner declined (`:19`) |
| `SampleFolderScanner` | `lib/infrastructure/memory/sample_folder_scanner.dart:5-12` | Exactly `SampleFolderScanner.ref` (`id: 'sample'`, `:6`) | Any other ref (`:10`) |
| `BrowserFolderScanner` | `lib/infrastructure/web/browser_folder_scanner.dart:17-40` | Refs issued by the browser registry: directory handles, dropped directory entries, or picked file lists (`:24-39`) | Ref not in its registry (`:25-26`) |
| `LocalFolderScanner` | `lib/infrastructure/io/local_folder_scanner.dart:15-54` | Refs issued by the local registry: a directory path or loose file paths (`:25-50`) | Ref is missing or no longer readable (`:26-27`, `:51-52`) |

Production wiring is `RoutingFolderScanner([SampleFolderScanner(),
platform.folderScanner])` (`lib/main.dart:33-36`), so the bundled sample and
the platform's folders share one port. Both scanners apply
`MarkdownFile.isMarkdown` to every file and `HiddenFolders` while walking
directories; the browser scanner also applies `HiddenFolders.hidesPath` to
picked-file paths (`lib/infrastructure/web/browser_folder_scanner.dart:80-81`),
while the local scanner does not need to because loose files carry only a base
name (`lib/infrastructure/io/local_folder_scanner.dart:37-45`) — an
optimisation that borrows domain rules, not a second copy of them.

## LibraryRepository

Holds the library currently open in the reader
(`lib/application/ports/library_repository.dart:4-7`).

| Member | Type | Contract |
|--------|------|----------|
| `save(Library library)` | `Future<void>` | Atomically replace the current session aggregate after a mutation. |
| `current()` | `Future<Library?>` | The library last saved, or `null` before any save. |

### Implementations

| Adapter | Defined at | Storage | Survives |
|---------|------------|---------|----------|
| `InMemoryLibraryRepository` | `lib/infrastructure/memory/in_memory_library_repository.dart:5-16` | The library projection in shared `InMemoryReaderState` (`:7-16`) | The session only |

## MarkdownScanner

Reads one markdown offered directly rather than beneath a folder
(`lib/application/ports/markdown_scanner.dart:30-33`). `MarkdownRef` is the
opaque handle; `ScannedMarkdown` returns its display name, text and optional
physical source identity (`lib/application/ports/markdown_scanner.dart:3-28`).

| Adapter | Identity behavior |
|---------|-------------------|
| `LocalMarkdownScanner` | normalized absolute local path, case-folded on Windows (`lib/infrastructure/io/local_markdown.dart:17-23`) |
| `BrowserMarkdownScanner` | handle-based identity when the browser exposes a persistent file handle; `null` for legacy upload files (`lib/infrastructure/web/browser_markdown_scanner.dart:15-30`) |

The application treats a missing source identity as unknown, never as
permission to deduplicate by filename.

## DocumentParser

Turns markdown source into the blocks a reader meets
(`lib/application/ports/document_parser.dart:7-9`). It has a document of its
own, because the reason it is a port at all takes explaining:
[Document Parser Port](04-document-parser-port.md).

| Member | Type | Contract |
|--------|------|----------|
| `parse(String markdown)` | `DocumentContent` | Blocks in source order, carrying the author's text exactly. Never throws; unmapped markup becomes `RawBlock`. |

### Implementations

| Adapter | Defined at | Notes |
|---------|------------|-------|
| `MarkdownDocumentParser` | `lib/infrastructure/markdown/markdown_document_parser.dart:17-47` | `package:markdown`, GitHub-flavoured; front matter skipped (`:32-46`) |

There is no parser test double. The implementation is `const`, has no I/O, and
is used directly by the use-case tests
(`test/application/use_cases_test.dart:399-406`).

## DocumentSearch

Finds a literal in the visible text of application-scoped documents
(`lib/application/ports/document_search.dart:4-13`). Its dedicated document
records why matching belongs behind a port and the stable offset contract:
[Document Search Port](06-document-search-port.md).

| Member | Type | Contract |
|--------|------|----------|
| `find(query, documents)` | `Future<List<DocumentSearchResult>>` | Preserve document and occurrence order, omit documents without matches, and return offsets into visible text. |

The production implementation is `LiteralDocumentSearch`
(`lib/infrastructure/search/literal_document_search.dart:9-44`).

## Workspace ports

Workspace use cases need two kinds of outside help: access to the user's JSON
file, and fresh platform permission to reach the folders and markdown it names.
The ports keep both concerns out of the domain model:

| Port | Responsibility |
|------|----------------|
| `WorkspaceCodec` | Encode and decode the public workspace document (`lib/application/ports/workspace_codec.dart:3-7`). |
| `WorkspaceFiles` | Select, read, and write a user-owned workspace file (`lib/application/ports/workspace_files.dart:22-31`). |
| `WorkspaceIds` | Create opaque workspace and source identities without coupling the domain to randomness (`lib/application/ports/workspace_ids.dart:3-7`). |
| `WorkspaceSourceAccess` | Locate, bind, restore, and reconnect machine-local source handles (`lib/application/ports/workspace_source_access.dart:18-57`). |
| `WorkspaceSessionRepository` | Hold the current workspace, its file binding, dirty state, and unavailable sources (`lib/application/ports/workspace_session_repository.dart:5-35`). |
| `WorkspaceRestoration` | Replace the Library and WorkspaceSession projections together after a complete restore (`lib/application/ports/workspace_restoration.dart:4-7`). |
| `WorkspaceMutationCommitter` | Synchronize durable workspace intent before a library mutation becomes visible (`lib/application/ports/workspace_mutation_committer.dart:6-18`). |

Their orchestration is documented in [Workspace Lifecycle](09-workspace-lifecycle.md).

## Possible future ports

| Need | Likely port | Driven by |
|------|-------------|-----------|
| Publish domain events | `EventPublisher` | [Plugin Architecture](../07-roadmap/01-plugin-architecture.md) |
| Report scan progress for large folders | `ScanProgress` | [Library Mutations](01-library-mutations.md) |

These are directions rather than reserved interfaces. A port should appear only
when a concrete use case needs it, as described in
[Writing Docs](../09-contributing/04-writing-docs.md).
