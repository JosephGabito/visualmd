# Infrastructure

Infrastructure is where Visual MD meets the outside world. The application asks
for a capability such as “scan this folder” or “save this workspace”; an adapter
answers using browser APIs, desktop files, or an in-process implementation.

That separation keeps the reading model independent of any one platform. An
adapter translates platform details into the values understood by
[Application](../02-application/README.md) and
[Domain](../01-domain/README.md), then gets out of the way.

## On this shelf

| Document | What it introduces |
|----------|--------------------|
| [Platform Adapters](01-platform-adapters.md) | The object assembled for one target and the compile-time choice between web and desktop |
| [Folder Registry](02-folder-registry.md) | How native folder handles travel through the application as small, opaque `FolderRef` values |
| [Workspace Persistence](03-workspace-persistence.md) | Portable workspace JSON, machine-local access records, save, open, and recovery |
| [Quiet Viewport Geometry](04-quiet-viewport-geometry.md) | Stable block geometry, anchor compensation, and scrollbar interaction epochs |
| [Chunked Document Source](05-chunked-document-source.md) | Append-efficient source storage and bounded parser windows |
| [Web Adapters](web/README.md) | Browser drag-and-drop, picking, scanning, links, and workspace files |
| [Desktop Adapters](desktop/README.md) | Local files, native dialogs, window chrome, and macOS sandbox access |
| [Memory Adapters](memory/README.md) | Session state, scanner routing, and the bundled welcome library |
| [Markdown Adapter](markdown/README.md) | Turning Markdown source into the domain's document blocks |
| [Search Adapter](search/README.md) | Literal matching over the text produced by the Markdown parser |

## How the pieces meet

Folder sources have the same application-facing shape on every platform. A web
drop, a desktop directory, and the bundled sample each become a `FolderRef` and
are read through `FolderScanner`. Direct Markdown files follow the parallel
`MarkdownRef` and `MarkdownScanner` path. The native handles stay in a registry,
so neither the domain nor the use cases need to understand a browser `File` or
a filesystem path.

| Family | Platform handle | Scanner |
|--------|-----------------|---------|
| Web | `BrowserFolder` (`HandleDirectory`, `DroppedDirectory`, or `PickedFiles`) — `lib/infrastructure/web/browser_folder.dart` | `BrowserFolderScanner` — `lib/infrastructure/web/browser_folder_scanner.dart` |
| Desktop | `LocalFolder` (`LocalDirectory` or `LocalFiles`) — `lib/infrastructure/io/local_folder.dart` | `LocalFolderScanner` — `lib/infrastructure/io/local_folder_scanner.dart` |
| Memory | The sample uses a constant reference rather than a native handle — `lib/infrastructure/memory/sample_folder_scanner.dart` | `SampleFolderScanner` — `lib/infrastructure/memory/sample_folder_scanner.dart` |

`RoutingFolderScanner` presents those folder scanners as one port
(`lib/infrastructure/routing_folder_scanner.dart`). The composition root
combines the sample and platform scanners, then passes the result to `AddFolder`
(`lib/main.dart`, `lib/main.dart`). Direct files use the platform's
Markdown scanner (`lib/main.dart`, `lib/main.dart`).

Images keep that same authority without making scanners read every binary in a
library. `RoutingDocumentImageLoader` tries the bundled sample and then the
platform adapter on demand. Desktop resolves canonical files inside the
offered source; web traverses its retained handle or selected file list
(`lib/infrastructure/routing_document_image_loader.dart`,
`lib/application/ports/document_image_loader.dart`).

After bytes have been read, the other adapters take over. The
[Markdown Adapter](markdown/README.md) implements
[Document Parser Port](../02-application/04-document-parser-port.md) on every
platform, and the [Search Adapter](search/README.md) implements
[Document Search Port](../02-application/06-document-search-port.md) over the
parsed result.

## A useful boundary

Infrastructure may depend on application ports and domain values, while the
inner rings remain unaware of infrastructure. Platform-specific UI needs are
offered as small wrapper functions: the API can apply a desktop drop target or
window drag region without importing the plugin that created it. The complete
dependency map lives in [Dependency Direction](../00-foundation/03-dependency-direction.md).

This is also where edge rules are applied consistently. Folder scanners use the
domain's `MarkdownFile` and `HiddenFolders` rules rather than maintaining their
own definitions. Future sources can therefore join the same pipeline without
changing what Visual MD considers a document or a library.
