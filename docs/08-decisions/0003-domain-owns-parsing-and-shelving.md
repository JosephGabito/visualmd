# 0003 — Domain Owns Parsing and Shelving

Status: Accepted · 2026-08-22

## Context

Every platform hands the app files differently: the browser gives directory
entries or a flat file list with relative paths; the desktop gives paths on
disk. The tempting shortcut is to let each adapter build the tree it is
looking at and hand the UI something ready to draw. That puts the rules of
the product — what is a markdown file, what is ordered before what, where a
heading starts — in two or three places at once, each subtly different.

## Decision

Adapters move bytes. The domain decides. Concretely, these rules live in
`domain/` and nowhere else, each with a unit test:

| Rule | Home |
|------|------|
| What counts as a markdown file (`.md`, `.markdown`, `.mdown`, `.mkd`, case-insensitive) | `MarkdownFile` |
| Which folders are never shelved (dot-prefixed or recognised dependency/runtime trees) | `HiddenFolders` |
| Natural ordering (`2-setup` before `10-deploy`) | `NaturalOrder` |
| READMEs first on their shelf; the root README opens first | `LibraryBuilder`, `Library.openingDocument` |
| Folders with nothing readable beneath them are pruned | `LibraryBuilder` |
| Duplicate paths: first one wins; separators normalised | `LibraryBuilder`, `DocumentId` |
| Headings, anchors, front matter, sections | `DocumentOutline` |
| Relative link resolution | `DocumentId.resolve` |

Adapters return a flat `ScannedFolder` of `FileEntry(path, content)` and the
use case calls `LibraryBuilder.buildRoot`. An adapter may *consult* a domain rule
to avoid reading bytes the domain would discard; it may not *restate* one.

## Consequences

- Two platforms, one tree-building algorithm, one set of tests. The desktop
  scanner test only checks that the right files were read; it does not need
  to re-test ordering.
- Adding a file type is a one-line change in `MarkdownFile.extensions`; every
  adapter obeys it automatically.
- The domain depends on nothing, so these tests run in milliseconds with no
  Flutter binding.
- The cost is that adapters read every candidate file's content up front
  rather than lazily. For folders of markdown this is negligible; for a
  monorepo it is bounded by the hidden-folder rule.

## Evidence

- Adapters produce raw entries; the domain shelves them:
  `lib/domain/library/library_builder.dart:10-16`,
  `lib/application/use_cases/add_folder.dart:40-50`.
- Filtering, pruning and ordering in one place: `lib/domain/library/library_builder.dart:29-33`, `lib/domain/library/library_builder.dart:60-72`.
- The rules themselves: `lib/domain/library/markdown_file.dart:3-9`, `lib/domain/library/hidden_folders.dart:3-35`, `lib/domain/library/natural_order.dart:6-17`, `lib/domain/library/library.dart:22-30`.
- Adapters consulting, not restating: `lib/infrastructure/io/local_folder_scanner.dart` and `lib/infrastructure/web/browser_folder_scanner.dart` import `MarkdownFile` and `HiddenFolders`.
- Tests: `test/domain/library_builder_test.dart:7-153`, `test/domain/document_outline_test.dart:8-110`.
- Written rules: [Shelving Rules](../01-domain/02-shelving-rules.md), [Document Outline](../01-domain/03-document-outline.md).
