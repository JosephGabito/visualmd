# Ports

A port is an interface the application needs, named for the need. The
application owns the contract; infrastructure supplies implementations; the
composition root chooses which (`lib/main.dart`).

## FolderScanner

Reads the files beneath a folder the reader offered
(`lib/application/ports/folder_scanner.dart`).

| Member | Type | Contract |
|--------|------|----------|
| `scan(FolderRef ref)` | `Future<ScannedFolder>` | Return every file the adapter can read beneath the ref, or throw `FolderUnavailable`. Adapters may skip files the domain would discard; they must not sort or prune folders. |

`FolderMetadataScanner` is the optional two-phase form of this capability.
`scanMetadata` may return `titlesDeferred: true` after discovering paths and
physical identities without reading document bytes. `enrichTitles` completes
the same ordered snapshot with authored titles. Callers that receive an
ordinary `FolderScanner` keep the one-phase contract; routing falls back to it
without inventing deferred work (`lib/application/ports/folder_scanner.dart`,
`lib/infrastructure/routing_folder_scanner.dart`).

### Value types

| Type | Defined at | Meaning |
|------|------------|---------|
| `FolderRef(id, name)` | `lib/application/ports/folder_scanner.dart` | Opaque handle. Equality and hash by `id` only (`lib/application/ports/folder_scanner.dart`). The `name` is what the library will be called. |
| `ScannedFolder(name, files, titlesDeferred)` | `lib/application/ports/folder_scanner.dart` | Name plus a flat list of metadata-first `FileEntry`; `titlesDeferred` distinguishes a publishable filename snapshot from a title-complete result. Bundled sources may embed content (`lib/domain/library/library_builder.dart`). |
| `DeferredFolderTitles(ref, metadata)` | `lib/application/ports/folder_scanner.dart` | The opaque source capability paired with the exact publishable snapshot whose titles remain to be read. |
| `FolderUnavailable(ref)` | `lib/application/ports/folder_scanner.dart` | The ref is unknown to this scanner, or the folder is gone. |

### Implementations

| Adapter | Defined at | Recognises | Throws `FolderUnavailable` when |
|---------|------------|------------|---------------------------------|
| `RoutingFolderScanner` | `lib/infrastructure/routing_folder_scanner.dart` | Whatever any scanner in its list recognises; tries each in order and moves on when one throws `FolderUnavailable` (`lib/infrastructure/routing_folder_scanner.dart`) | Every scanner declined (`lib/infrastructure/routing_folder_scanner.dart`) |
| `SampleFolderScanner` | `lib/infrastructure/memory/sample_folder_scanner.dart` | Exactly `SampleFolderScanner.ref` (`id: 'sample'`, `lib/infrastructure/memory/sample_folder_scanner.dart`) | Any other ref (`lib/infrastructure/memory/sample_folder_scanner.dart`) |
| `BrowserFolderScanner` | `lib/infrastructure/web/browser_folder_scanner.dart` | Refs issued by the browser registry: directory handles, dropped directory entries, or picked file lists (`lib/infrastructure/web/browser_folder_scanner.dart`) | Ref not in its registry (`lib/infrastructure/web/browser_folder_scanner.dart`) |
| `LocalFolderScanner` | `lib/infrastructure/io/local_folder_scanner.dart` | Refs issued by the local registry: a directory path or loose file paths (`lib/infrastructure/io/local_folder_scanner.dart`) | Ref is missing or no longer readable (`lib/infrastructure/io/local_folder_scanner.dart`, `lib/infrastructure/io/local_folder_scanner.dart`) |

Production wiring is `RoutingFolderScanner([SampleFolderScanner(),
platform.folderScanner])` (`lib/main.dart`), so the bundled sample and
the platform's folders share one port. Both scanners apply
`MarkdownFile.isMarkdown` to every file and `HiddenFolders` while walking
directories; the browser scanner also applies `HiddenFolders.hidesPath` to
picked-file paths (`lib/infrastructure/web/browser_folder_scanner.dart`),
while the local scanner does not need to because loose files carry only a base
name (`lib/infrastructure/io/local_folder_scanner.dart`) — an
optimisation that borrows domain rules, not a second copy of them.

## FolderDocumentScanner

Reads one Markdown source inside an already-open folder
(`lib/application/ports/folder_document_scanner.dart`). A full
`FolderScanner` builds the shelf without retaining bytes; this port supplies
the exact document later when reading, search, or source synchronization needs
it.

| Member | Type | Contract |
|--------|------|----------|
| `scanDocument(folder, relativePath)` | `Future<ScannedFolderDocument?>` | Return content and physical identity for one readable Markdown, or `null` when the path no longer names one. |

Desktop and browser folder scanners implement both contracts. The relative
path remains scoped to its offered root; infrastructure owns filesystem,
browser-handle, bookmark and traversal safety.

## LibraryRepository

Holds the library currently open in the reader
(`lib/application/ports/library_repository.dart`).

| Member | Type | Contract |
|--------|------|----------|
| `save(Library library)` | `Future<void>` | Atomically replace the current session aggregate after a mutation. |
| `current()` | `Future<Library?>` | The library last saved, or `null` before any save. |

### Implementations

| Adapter | Defined at | Storage | Survives |
|---------|------------|---------|----------|
| `InMemoryLibraryRepository` | `lib/infrastructure/memory/in_memory_library_repository.dart` | The library projection in shared `InMemoryReaderState` (`lib/infrastructure/memory/in_memory_library_repository.dart`) | The session only |

## MarkdownScanner

Reads one markdown offered directly rather than beneath a folder
(`lib/application/ports/markdown_scanner.dart`). `MarkdownRef` is the
opaque handle; `ScannedMarkdown` returns its display name, text and optional
physical source identity (`lib/application/ports/markdown_scanner.dart`).

| Adapter | Identity behavior |
|---------|-------------------|
| `LocalMarkdownScanner` | normalized absolute local path, case-folded on Windows (`lib/infrastructure/io/local_markdown.dart`) |
| `BrowserMarkdownScanner` | handle-based identity when the browser exposes a persistent file handle; `null` for legacy upload files (`lib/infrastructure/web/browser_markdown_scanner.dart`) |

The application treats a missing source identity as unknown, never as
permission to deduplicate by filename.

## DocumentParser

Turns markdown source into the blocks a reader meets
(`lib/application/ports/document_parser.dart`). It has a document of its
own, because the reason it is a port at all takes explaining:
[Document Parser Port](04-document-parser-port.md).

| Member | Type | Contract |
|--------|------|----------|
| `parse(String markdown)` | `DocumentContent` | Blocks in source order, carrying the author's text exactly. Never throws; unmapped markup becomes `RawBlock`. |

### Implementations

| Adapter | Defined at | Notes |
|---------|------------|-------|
| `MarkdownDocumentParser` | `lib/infrastructure/markdown/markdown_document_parser.dart` | `package:markdown`, GitHub-flavoured; front matter skipped (`lib/infrastructure/markdown/markdown_document_parser.dart`) |

There is no parser test double. The implementation is `const`, has no I/O, and
is used directly by the use-case tests
(`test/application/use_cases_test.dart`).

## DocumentSearch

Finds a literal in the visible text of application-scoped documents
(`lib/application/ports/document_search.dart`). Its dedicated document
records why matching belongs behind a port and the stable offset contract:
[Document Search Port](06-document-search-port.md).

| Member | Type | Contract |
|--------|------|----------|
| `find(query, documents)` | `Future<List<DocumentSearchResult>>` | Preserve document and occurrence order, omit documents without matches, and return offsets into visible text. |

The production implementation is `LiteralDocumentSearch`
(`lib/infrastructure/search/literal_document_search.dart`).

## DocumentImageLoader

Reads one image named by a parsed document without granting the API ring direct
filesystem or browser access (`lib/application/ports/document_image_loader.dart`).

| Member | Type | Contract |
|--------|------|----------|
| `load(document, source)` | `Future<Uint8List?>` | Return the bytes reachable through the document's offered source, or `null` when the destination is missing, unsafe, or unavailable. |

`DocumentImagePath.resolve` supplies the shared portable rule. Destinations
begin beside the Markdown document; percent-encoded path segments are decoded;
dot segments may move within the opened root. Schemes, authorities, absolute
paths, encoded separators, and a parent step above that root are not local
assets. Remote HTTP and HTTPS sources bypass this port and remain network
images at the API edge.

Production composes `SampleDocumentImageLoader` before the platform loader
through `RoutingDocumentImageLoader` (`lib/main.dart`). Desktop reads only
canonical files inside an offered directory or an explicitly offered loose
file set. Browser adapters traverse the retained folder handle or selected
file list. A directly uploaded browser Markdown has no parent-directory
capability, so its neighbouring images remain unavailable rather than being
guessed from a local path.

## DocumentViewportGeometry

Keeps rendering-physics policy out of the Flutter API and the document domain
(`lib/application/ports/document_viewport_geometry.dart`). The port speaks in
stable `DocumentBlockId` values, revisions, estimated and measured extents,
anchor corrections, and frozen scrollbar geometry.

| Member | Contract |
|--------|----------|
| `appendAll(seeds)` | Add newly committed or provisional block identities without rebuilding their prefix. |
| `replaceTail(start, seeds, anchor)` | Truncate and replace a provisional suffix while retaining measured prefix geometry and returning exact anchor correction. |
| `reset(seeds, layoutRevision, anchor)` | Reconcile a structural snapshot, retaining measured extents for unchanged identities and returning the prefix delta before the retained anchor. |
| `leadingOffsetOf(id)` | Return the prefix extent before one stable block identity. |
| `indexOf(id)` | Return one stable identity's current sequence position without scanning. |
| `blockAtOffset(offset)` | Find the stable identity occupying a content coordinate without scanning its prefix. |
| `revise(seed, anchor)` | Replace one item's estimate under a newer item revision and return its anchor correction. |
| `relayout(revision, estimates, anchor)` | Replace all estimates atomically for a new width, type, or theme epoch. |
| `measure(...)` | Accept current-revision geometry, reject stale results, and return the exact content and anchor correction. |
| `freeze(viewportExtent)` | Capture this ledger's logical scroll metrics for one interaction. |
| `freezeMetrics(contentExtent, viewportExtent)` | Capture already-known physical scroll dimensions without exposing the geometry engine to the API. |

`QuietDocumentViewportGeometryFactory` is the production adapter and is wired
at the composition root (`lib/infrastructure/viewport/quiet_document_viewport_geometry.dart`,
`lib/main.dart`). Its algorithm and the visible-interaction contract are
documented in [Quiet Viewport Geometry](../03-infrastructure/04-quiet-viewport-geometry.md).

## Workspace ports

Workspace use cases need two kinds of outside help: access to the user's JSON
file, and fresh platform permission to reach the folders and markdown it names.
The ports keep both concerns out of the domain model:

| Port | Responsibility |
|------|----------------|
| `WorkspaceCodec` | Encode and decode the public workspace document (`lib/application/ports/workspace_codec.dart`). |
| `WorkspaceFiles` | Select, read, and write a user-owned workspace file (`lib/application/ports/workspace_files.dart`). |
| `WorkspaceIds` | Create opaque workspace and source identities without coupling the domain to randomness (`lib/application/ports/workspace_ids.dart`). |
| `WorkspaceSourceAccess` | Locate, bind, restore, and reconnect machine-local source handles (`lib/application/ports/workspace_source_access.dart`). |
| `WorkspaceSessionRepository` | Hold the current workspace, its file binding, dirty state, and unavailable sources (`lib/application/ports/workspace_session_repository.dart`). |
| `WorkspaceRestoration` | Replace the Library and WorkspaceSession projections together after a complete restore (`lib/application/ports/workspace_restoration.dart`). |
| `WorkspaceMutationCommitter` | Synchronize durable workspace intent before a library mutation becomes visible (`lib/application/ports/workspace_mutation_committer.dart`). |

Their orchestration is documented in [Workspace Lifecycle](09-workspace-lifecycle.md).

## ShelfSourceActions

Shelf context commands need a physical path on desktop without teaching the
domain or API what a local path looks like. `ShelfSourceActions` accepts a
root-relative folder or document location, resolves an absolute path when the
platform owns one, and reveals that source through the native file manager
(`lib/application/ports/shelf_source_actions.dart`). The sample library and
browser sources simply have no physical capability; copying the portable
relative path still belongs to the shelf itself.

Desktop resolves the opaque root through the same folder and Markdown
registries used by scanners. A security-scoped bookmark surrounds the reveal
operation when a Finder drop supplied one
(`lib/infrastructure/io/desktop_shelf_source_actions.dart`).

## Possible future ports

| Need | Likely port | Driven by |
|------|-------------|-----------|
| Publish domain events | `EventPublisher` | [Plugin Architecture](../07-roadmap/01-plugin-architecture.md) |
| Report scan progress for large folders | `ScanProgress` | [Library Mutations](01-library-mutations.md) |

These are directions rather than reserved interfaces. A port should appear only
when a concrete use case needs it, as described in
[Writing Docs](../09-contributing/04-writing-docs.md).
