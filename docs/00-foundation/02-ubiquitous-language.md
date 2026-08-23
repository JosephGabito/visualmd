# Ubiquitous Language

Shared names make it easier to move between the interface, code, tests, and
documentation without translating the same idea each time. The final column in
these tables lists nearby words that usually mean something different here.
They are guidance for clear naming, not a ban on natural prose.

## Rings

Five directories under `lib/`, plus the composition root. "Ring" is the word;
"layer" and "tier" are not. See
[Dependency Direction](03-dependency-direction.md).

| Ring | Holds | Framework-free |
|------|-------|----------------|
| `domain/` | The library, documents, outlines, and the rules about them. | yes |
| `application/` | Use cases and the ports they declare. | yes in practice |
| `presentation/` | Portable definitions a contribution is written against — today, what a theme is. | yes, checked |
| `api/` | The Flutter shell: widgets, controller, theme binding. | no |
| `infrastructure/` | Adapters that implement ports and touch the platform. | no |

## Domain terms

| Term | Meaning | Lives in | Prefer over |
|------|---------|----------|--------------------|
| **Workspace** | The durable reading room: ordered source membership, theme, and active document address, without document contents or platform authority. | `lib/domain/workspace/workspace.dart:5-48` | project, vault, repo, library |
| **Workspace source** | One stable folder or standalone Markdown membership addressed relative to the document root. | `lib/domain/workspace/workspace_source.dart:3-21` | path entry, mount |
| **Library** | The current in-memory projection: scanned standalone markdowns and available folder roots with their documents. | `lib/domain/library/library.dart:7-74` | workspace, project, vault, repo |
| **Library root** | One independently opened top-level folder, identified separately from its display name. | `lib/domain/library/library_root.dart:6-34` | project, source |
| **Folder** | A shelf: a folder holding documents and sub-folders. Only exists if something readable is beneath it. | `lib/domain/library/folder.dart:6-40` | directory (in domain code), group, node |
| **Document** | A markdown file with its full content and a lazily parsed outline. | `lib/domain/library/document.dart:6-30` | file, page, note, article |
| **DocumentId** | A document's identity: its root id plus `/`-separated path inside that root. Resolves relative links without crossing roots. | `lib/domain/library/document_id.dart:3-60` | path (as an identity), key, slug |
| **DocumentSourceId** | Optional opaque physical-source identity used to reconcile direct and folder scans without filename guesses. | `lib/domain/library/document_source_id.dart:1-17` | path, document id |
| **FileEntry** | Raw path, content and optional source identity from a folder scanner, before the domain decides what becomes of it. | `lib/domain/library/library_builder.dart:11-18` | raw file, blob, item |
| **LibraryBuilder** | Turns one folder's file entries into a `LibraryRoot`: filters, prunes, orders. | `lib/domain/library/library_builder.dart:19-54` | importer, loader, indexer |
| **DocumentOutline** (Outline) | A document's structure for navigation: front matter set aside, a table of contents, and sections. | `lib/domain/reading/document_outline.dart:7-17` | AST, tree, index |
| **TableOfContents** | The ordered headings of one document. | `lib/domain/reading/table_of_contents.dart:3-22` | TOC is acceptable in UI labels only; never "index" |
| **Heading** | One navigable entry: level 1–6, plain text, unique GitHub-style anchor, source line. | `lib/domain/reading/heading.dart:2-24` | title (for non-h1), header |
| **Section** | A heading plus everything up to the next heading. Still produced by the outline; no longer what the page renders. | `lib/domain/reading/section.dart:5-12` | chunk, part |
| **DocumentContent** | A document as the page is built from it: an ordered list of blocks. | `lib/domain/reading/content/document_content.dart:4-18` | AST, tree, model |
| **Block** | One shape on the page: a paragraph, a heading, a code block, a quotation, a list, a table, a rule. | `lib/domain/reading/content/block.dart:4-9` | node, element |
| **Run** (`Inline`) | What a line of text is made of: text, code, a mark, a link, an image, a break. | `lib/domain/reading/content/inline.dart:5-85` | span (that is the Flutter word, used only in the renderer), token |
| **HeadingAnchors** | The one rule that turns a heading into a slug a link can reach. | `lib/domain/reading/heading_anchor.dart:7-29` | slugger |
| **DocumentParser** | The port that turns markdown source into blocks. | `lib/application/ports/document_parser.dart:7-9` | renderer, formatter |
| **SearchQuery** | A non-empty literal the reader is looking for. | `lib/domain/search/search_result.dart:3-12` | pattern, expression |
| **TextMatch** | One half-open offset range in the visible text of a document. | `lib/domain/search/search_result.dart:14-28` | hit, occurrence result |
| **ReadingTheme** | Every style and gap the page is set with, derived from a theme, scale and active text scaler. | `lib/api/render/reading_theme.dart:19-81` | style sheet |
| **Hidden folder** | A folder the library never shelves: dot-prefixed or a recognised dependency/runtime tree. | `lib/domain/library/hidden_folders.dart:3-35` | ignored, excluded, blacklisted |
| **Natural order** | Case-insensitive ordering with embedded numbers compared by value. | `lib/domain/library/natural_order.dart:3-18` | alphabetical, smart sort |

## Application terms

| Term | Meaning | Lives in | Prefer over |
|------|---------|----------|--------------------|
| **FolderRef** | An opaque handle to a folder the reader offered. Only the adapter that issued it knows what it points at. | `lib/application/ports/folder_scanner.dart:5-19` | handle (in prose it is fine; in code the type is `FolderRef`), path, URL |
| **FolderScanner** | Port: read the files beneath a `FolderRef`. | `lib/application/ports/folder_scanner.dart:30-32` | loader, reader, file service |
| **ScannedFolder** | What a scanner returns: a name and file entries. | `lib/application/ports/folder_scanner.dart:22-27` | result, payload |
| **FolderUnavailable** | The scanner does not recognise the ref, or the folder is gone. | `lib/application/ports/folder_scanner.dart:35-41` | not found (that is `DocumentNotFound`) |
| **MarkdownRef** | An opaque handle to one directly offered markdown. | `lib/application/ports/markdown_scanner.dart:3-15` | path, URL |
| **MarkdownScanner** | Port: read one direct markdown and its optional physical-source identity. | `lib/application/ports/markdown_scanner.dart:17-33` | file reader, loader |
| **LibraryRepository** | Port: hold the library currently open. | `lib/application/ports/library_repository.dart:4-7` | store, state, cache |
| **AddFolder** | Use case: scan one root, absorb matching standalone sources, append or refresh, synchronize the workspace, and return the reading choice. | `lib/application/use_cases/add_folder.dart:33-104` | open, load, import |
| **AddMarkdown** | Use case: add one standalone source or resolve it to the same document already inside a root. | `lib/application/use_cases/add_markdown.dart:28-81` | open file, import |
| **RemoveFolder** | Use case: remove one session root without touching disk and choose a neighboring reading when needed. | `lib/application/use_cases/remove_folder.dart:19-71` | delete folder |
| **RemoveMarkdown** | Use case: remove one standalone document from the session without touching disk and choose the next reading when needed. | `lib/application/use_cases/remove_markdown.dart:18-62` | delete file |
| **MoveFolder** | Use case: arrange top-level root order without changing nested order or the selected document. | `lib/application/use_cases/move_folder.dart:11-36` | sort |
| **ReadDocument** | Use case: fetch a document, its outline, and parsed content from the current library. | `lib/application/use_cases/read_document.dart:39-59` | get, fetch, view |
| **DocumentReading** | What `ReadDocument` returns: the document, outline, and content blocks. | `lib/application/use_cases/read_document.dart:9-20` | view model, DTO |
| **DocumentSearch** | Port: find a literal in visible document text. | `lib/application/ports/document_search.dart:4-13` | grep, finder service |
| **SearchDocuments** | Use case: choose one-document or whole-library scope, then search it. | `lib/application/use_cases/search_documents.dart:8-33` | global find, grep |
| **WorkspaceSession** | The current Workspace plus its selected file, dirty state, and unavailable source identities. | `lib/application/ports/workspace_session_repository.dart:5-35` | database row, project state |
| **WorkspaceFiles** | Port: select, read, and write user-owned workspace documents. | `lib/application/ports/workspace_files.dart:22-31` | file service |
| **WorkspaceSourceAccess** | Port: locate, bind, restore, and reconnect machine authority for durable source identities. | `lib/application/ports/workspace_source_access.dart:18-64` | path store, permission service |

## Infrastructure terms

| Term | Meaning | Lives in | Prefer over |
|------|---------|----------|--------------------|
| **Adapter** | A concrete implementation of a port, or a platform-facing helper that feeds one. | `lib/infrastructure/` | service, provider, driver |
| **FolderRegistry** | Issues `FolderRef`s for platform handles; one per adapter family. | `lib/infrastructure/folder_registry.dart:6-20` | cache, map |
| **MarkdownRegistry** | Issues `MarkdownRef`s for platform file handles, preserving stable identity where available. | `lib/infrastructure/markdown_registry.dart:3-24` | cache, map |
| **PlatformAdapters** | Everything the composition root needs from the current platform family. | `lib/infrastructure/platform/platform_adapters.dart:9-55` | platform service, environment |
| **ReaderFiles** | The reader's own files on disk: preferences, themes, and machine-local workspace access records. | `lib/infrastructure/io/reader_files.dart:11-149` | storage, settings service |
| **LiteralDocumentSearch** | Adapter using Dart's escaped, case-insensitive regular-expression engine over visible text. | `lib/infrastructure/search/literal_document_search.dart:7-55` | grep, index |
| **Composition root** | `lib/main.dart` — the only file that sees every ring. | `lib/main.dart:42-220` | bootstrap, DI container, app module |

## UI terms

| Term | Meaning | Lives in |
|------|---------|----------|
| **Shelf** | The left panel: standalone markdowns, then arranged roots and each root's nested tree. | `lib/api/widgets/shelf_panel.dart:14-35` |
| **Minimized** | A folder root showing only its own row; every document and descendant is hidden. | `lib/api/widgets/shelf_panel.dart:358-384` |
| **Expanded** | A root opened only far enough to reveal the active document: its ancestor chain is open and unrelated branches are minimized. | `lib/api/widgets/shelf_panel.dart:57-87` |
| **Page** | The middle column: the rendered document. | `lib/api/widgets/reading_pane.dart` |
| **Outline** | The right panel: the table of contents. | `lib/api/widgets/outline_panel.dart` |
| **Top bar** | The row with the shelf toggle, the theme picker and the outline toggle; on macOS it also hosts the traffic lights. | `lib/api/screens/reader_screen.dart` |
| **Search** | Literal find within the page or across the open library. | `lib/api/widgets/search_view.dart` |
| **Paper / Lamplight** | The two house themes: the light one and the dark one. | `lib/presentation/theme/built_in_themes.dart:9-41` |

## Theme terms

These live in the [presentation](../04-presentation/README.md) ring, which
holds portable definitions and no package dependencies. Their Flutter
counterparts are in `api/`.

| Term | Meaning | Lives in | Do not call it |
|------|---------|----------|----------------|
| **Theme** | A named set of colour tokens and typeface names, with a brightness. Data, never code. | `lib/presentation/theme/reader_theme.dart:10-86` | skin, style, mode |
| **ReaderTheme** | The class holding one theme. | `lib/presentation/theme/reader_theme.dart:10-86` | AppTheme |
| **ThemePalette** (Palette) | The nine semantic colour tokens of a theme. | `lib/presentation/theme/theme_palette.dart:7-122` | color scheme, swatch set |
| **Token** | One named colour in a palette — `paper`, `ink`, `accent`. Named for meaning, never for a widget. | `lib/presentation/theme/theme_palette.dart:8-34` | variable, colour slot |
| **ThemeTypefaces** | The three family names a theme sets: serif, sans, mono. | `lib/presentation/theme/theme_typefaces.dart:5-33` | fonts, typography |
| **ThemeChoice** | What the reader picked: one theme, or a light/dark pair that follows the system. | `lib/presentation/theme/theme_choice.dart:5-58` | theme mode |
| **ThemeRegistry** | Every theme available: built-ins, then user files that may replace them. | `lib/presentation/theme/theme_registry.dart:21-80` | theme manager, loader |
| **ThemeFormatException** | A theme document the reader could not use, with a reason its author can act on. | `lib/presentation/theme/theme_format_exception.dart:2-8` | parse error, invalid theme |
| **ThemeLoadError** | One skipped theme file: its origin and the reason. | `lib/presentation/theme/theme_registry.dart:10-17` | warning, failure |
| **LibraryPalette** | The Flutter `ThemeExtension` carrying a `ThemePalette` into the widget tree, read as `context.palette`. | `lib/api/theme/library_theme.dart:11-86` | theme data, colors |
| **LibraryTypefaces** | The Flutter `ThemeExtension` resolving family names to text styles, read as `context.type`. | `lib/api/theme/library_theme.dart:96-139` | text theme, fonts |

## Planned plugin terms

Direction only; none of these exist in code yet. See
[Plugin Architecture](../07-roadmap/01-plugin-architecture.md).

| Term | Meaning | Prefer over |
|------|---------|--------------------|
| **Event** | A typed record that something happened in the domain (`LibraryOpened`, `DocumentOpened`). | hook (string-named), action |
| **Reactor** | A plugin that subscribes to events and performs side effects. | listener, observer, action |
| **Extension point** | A typed registry the kernel consults for a value (e.g. "who renders `mermaid` fences?"). | filter |
| **Contributor** | A plugin registered into an extension point. | filter, provider |
| **Slot** | A named, enumerated place in the shell a plugin may render into. | region, zone, hook |
