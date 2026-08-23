# Invariants

This table connects each domain behaviour to the code that defines it and the
test that demonstrates it. Rows without direct coverage are called out
explicitly so a reader can distinguish implemented behaviour from verified
behaviour.

## Library module

| # | Invariant | Enforced at | Tested at |
|---|-----------|-------------|-----------|
| 1 | A `DocumentId` is `/`-separated, has no empty segments, and never starts with `/` | `lib/domain/library/document_id.dart:12-22` | `test/domain/library_builder_test.dart:94-105` |
| 2 | A `DocumentId` is never empty | `lib/domain/library/document_id.dart:12-16` | not directly tested — see Gaps |
| 3 | `DocumentId` equality includes both root identity and normalised path | `lib/domain/library/document_id.dart:52-57` | `test/application/use_cases_test.dart:104-124` |
| 4 | `resolve` never escapes or changes the owning library root | `lib/domain/library/document_id.dart:36-50` | `test/domain/library_builder_test.dart:107-117`, `test/api/reader_controller_library_test.dart:293-302` |
| 5 | `resolve` treats a leading `/` as its own root and decodes percent-encoding | `lib/domain/library/document_id.dart:36-49` | `test/domain/library_builder_test.dart:107-117` |
| 6 | Root identities are unique within a `Library` | `lib/domain/library/library.dart:12-20` | not directly tested — see Gaps |
| 7 | A new root appends; a known root refreshes without moving | `lib/domain/library/library.dart:76-84` | `test/application/use_cases_test.dart:104-160` |
| 8 | Moving a root never changes its nested order | `lib/domain/library/library.dart:109-117` | root order covered at `test/application/use_cases_test.dart:300-326`; nested identity follows by construction |
| 9 | A `Document` is always a markdown file | `lib/domain/library/document.dart:12-15` | `test/domain/document_outline_test.dart:154-159` |
| 10 | `Document.title` falls back to the file name without extension | `lib/domain/library/document.dart:22-28` | `test/domain/document_outline_test.dart:141-152` |
| 11 | Only recognised markdown extensions are shelved (`.md`, `.markdown`, `.mdown`, `.mkd`, any case) | `lib/domain/library/markdown_file.dart:3-9`, `lib/domain/library/library_builder.dart:33-37` | `test/domain/library_builder_test.dart:9-24` |
| 12 | Files under hidden dependency/runtime folders are never shelved; generic output folders remain visible | `lib/domain/library/hidden_folders.dart:3-35`, `lib/domain/library/library_builder.dart:33-37` | `test/domain/library_builder_test.dart:119-156` |
| 13 | Duplicate paths within one root keep the first entry | `lib/domain/library/library_builder.dart:31-37` | `test/domain/library_builder_test.dart:94-105` |
| 14 | A nested `Folder` is only built when at least one document is beneath it | `lib/domain/library/library_builder.dart:73-79` | `test/domain/library_builder_test.dart:9-24` |
| 15 | Nested folders and documents are in natural order; READMEs sort first | `lib/domain/library/library_builder.dart:73-85` | `test/domain/library_builder_test.dart:26-72` |
| 16 | A root opens its README, else its first document, else `null` | `lib/domain/library/library_root.dart:25-34` | `test/domain/library_builder_test.dart:74-92`, `:158-166` |
| 17 | `allDocuments` yields a folder's own documents before its sub-folders' | `lib/domain/library/folder.dart:26-32` | `test/domain/library_builder_test.dart:74-92` |
| 18 | `documentCount` counts every document beneath, recursively | `lib/domain/library/folder.dart:23-24` | `test/domain/library_builder_test.dart:9-24` |

## Reading module

| # | Invariant | Enforced at | Tested at |
|---|-----------|-------------|-----------|
| 19 | Headings inside fenced code blocks are not headings; a fence closes only with the same character and at least the same length | `lib/domain/reading/document_outline.dart:80-95` | `test/domain/document_outline_test.dart:35-59` |
| 20 | Closing hashes on ATX headings are not part of the text | `lib/domain/reading/document_outline.dart:147-152` | `test/domain/document_outline_test.dart:10-33` |
| 21 | Setext underlines turn paragraphs into headings, never rules, table separators or list items | `lib/domain/reading/document_outline.dart:61-66`, `:108-124` | `test/domain/document_outline_test.dart:61-80` |
| 22 | Heading text has inline markdown stripped | `lib/domain/reading/document_outline.dart:161-169` | `test/domain/document_outline_test.dart:10-33` |
| 23 | Anchors are unique within a document; the empty slug is `section` | `lib/domain/reading/heading_anchor.dart:11-29`, `lib/domain/reading/document_outline.dart:147-159` | `test/domain/document_outline_test.dart:82-92` |
| 24 | Every section includes its own heading line; leading prose is a heading-less section | `lib/domain/reading/document_outline.dart:171-190` | `test/domain/document_outline_test.dart:94-105` |
| 25 | Reference-link definitions appear in every section when there is more than one | `lib/domain/reading/document_outline.dart:183-187` | `test/domain/document_outline_test.dart:107-114` |
| 26 | Front matter is excluded from sections, and `title:` wins over the first h1 | `lib/domain/reading/document_outline.dart:20-43`, `:135-145` | `test/domain/document_outline_test.dart:116-124` |
| 27 | CRLF input parses the same as LF; an empty document has no sections and no title | `lib/domain/reading/document_outline.dart:52-56`, `:171-190` | `test/domain/document_outline_test.dart:126-138` |
| 28 | A document's outline is parsed at most once | `lib/domain/library/document.dart:22-24` | not directly tested (relies on `late final`) |

## Content module

| # | Invariant | Enforced at | Tested at |
|---|-----------|-------------|-----------|
| 29 | A heading's anchor is unique within its document, and `section` when its words slug to nothing | `lib/domain/reading/heading_anchor.dart:11-29` | `test/domain/document_outline_test.dart:82-92`, `test/infrastructure/markdown_document_parser_test.dart:82-108` |
| 30 | The outline and the content model derive anchors from the same rule, so a link in one resolves in the other | `lib/domain/reading/document_outline.dart:156`, `lib/infrastructure/markdown/markdown_document_parser.dart:115` | `test/application/use_cases_test.dart:399-413` |
| 31 | Anchor numbering is per document, never shared between documents | `lib/infrastructure/markdown/markdown_document_parser.dart:49-52` | `test/infrastructure/markdown_document_parser_test.dart:96-108` |
| 32 | A run of `CodeRun` carries its characters exactly, whatever they are | `lib/domain/reading/content/inline.dart:29-41` | `test/infrastructure/markdown_document_parser_test.dart:69-79` |
| 33 | A single newline inside a paragraph is a space, never a break | `lib/infrastructure/markdown/markdown_document_parser.dart:252-260` | `test/infrastructure/markdown_document_parser_test.dart:55-61` |
| 34 | Markup with no shape in the model is kept as words, never dropped | `lib/domain/reading/content/block.dart:123-130`, `lib/infrastructure/markdown/markdown_document_parser.dart:137-140`, `:298-307` | Untested — see Gaps |

## Gaps

- Row 34 has no test. Neither the block fallback (`RawBlock`) nor the inline
  one — an element with no shape keeping its children — is exercised by
  `test/infrastructure/markdown_document_parser_test.dart`. Raw HTML in a
  document is the case to write.

- Rows 2 and 6 lack direct constructor tests. Their checks are small, but tests
  would document the error behaviour as clearly as the happy paths.

- Row 28 relies on Dart's `late final` semantics. A direct behavioural test
  would require an observable parser count that the domain does not currently
  expose, so the construction itself is the evidence today.

See [Testing and Validation](../09-contributing/02-testing-and-validation.md)
for how these tables stay aligned with the implementation.
