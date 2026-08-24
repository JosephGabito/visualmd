# Testing and Validation

Visual MD uses several kinds of evidence because no single test can answer
every question. Domain tests state product rules, adapter tests exercise real
format and filesystem boundaries, widget tests protect interaction and
typography, and architecture tests keep dependencies pointing inward.

Start with the suite nearest your change. Run the complete project command
before review, then look at the result whenever a reader can see it.

## Fast feedback while working

```sh
flutter test test/domain
flutter test test/application
flutter test test/infrastructure
flutter test test/presentation
flutter test --name "every relative link"
```

`flutter test` without a path runs the complete suite. A focused run is for a
short feedback loop, not a different standard of correctness.

## Domain and application behavior

The domain suites describe the rules that stay the same on every platform:

- `library_builder_test.dart` covers Markdown filtering, hidden folders,
  natural shelf order, README placement, pruning, duplicate normalization,
  and root-scoped links (`test/domain/library_builder_test.dart:9-156`).
- `document_outline_test.dart` covers headings, anchors, front matter,
  sections, fences, and the Markdown-only invariant
  (`test/domain/document_outline_test.dart:8-121`).
- `workspace_test.dart` covers stable source order, unique identity,
  active-document membership, portable relative paths, and Windows root
  normalization (`test/domain/workspace_test.dart:14-98`).

Application tests use in-memory ports so they can focus on orchestration:

- `use_cases_test.dart` covers serialized library mutations, deterministic
  handoff, recovery after failures, document reads, and search scope
  (`test/application/use_cases_test.dart:90-259`).
- `workspace_use_cases_test.dart` covers New, Save, Save As, transactional
  open, unavailable sources, standalone absorption, deferred autosave,
  download-only web behavior, reconnect, and Windows-root handling
  (`test/application/workspace_use_cases_test.dart:54-596`).
- Reader-source tests prove mixed selections use the established add paths and
  a second Open request cannot race an active native picker
  (`test/api/reader_controller_library_test.dart:119-153`).

## Infrastructure boundaries

Adapter tests use concrete data at the boundary rather than repeating domain
rules:

- Desktop scanning uses a real temporary tree and covers nested Markdown,
  ignored files, malformed bytes, and unknown refs
  (`test/infrastructure/local_folder_scanner_test.dart:11-94`).
- The Markdown parser covers block and inline shapes from paragraphs through
  tables and full documents
  (`test/infrastructure/markdown_document_parser_test.dart:18-234`).
- Literal search checks the text a reader sees, case-insensitive matching, and
  library order (`test/infrastructure/literal_document_search_test.dart:13-56`).
- The workspace codec round-trips version one and rejects unknown fields,
  unsupported versions, and unsafe paths
  (`test/infrastructure/workspace_json_codec_test.dart:11-102`).
- Desktop workspace tests preserve the exact save-panel path, verify the macOS
  native-write message, and retain a last-good copy in the portable fallback
  (`test/infrastructure/desktop_workspace_files_test.dart:9-81`), while the
  reader-source picker proves native records become typed opaque refs
  (`test/infrastructure/desktop_reader_source_picker_test.dart:11-60`), and the
  command bridge proves native File-menu selections reach typed Dart commands
  (`test/infrastructure/desktop_commands_test.dart:9-45`).
- Registry tests ensure process handles retain durable source identities
  without aliasing paths across workspaces
  (`test/infrastructure/folder_registry_test.dart:6-70`).

## Interface and typography

Widget tests protect what a reader can observe:

- Theme, picker, text-size, font-metric, and brand tests cover the visual
  contract and bundled assets (`test/presentation/theme_test.dart:28-115`,
  `test/presentation/font_metrics_test.dart:18-81`,
  `test/presentation/brand_mark_test.dart:6-21`).
- Renderer tests cover column widths, table overflow, heading rhythm, inline
  punctuation, links, code selection, hanging marks, widows, quotations, and
  code scrolling (`test/presentation/document_view_test.dart:60-441`,
  `test/presentation/inline_composer_test.dart:49-338`,
  `test/presentation/paragraph_setting_test.dart:61-335`,
  `test/presentation/code_block_test.dart:55-88`).
- Chrome tests cover distinct Open shortcuts, the full launch composition,
  search, panel motion and resizing, error notices, compact-window behavior,
  and reduced-motion behavior
  (`test/presentation/reader_chrome_test.dart:248-579`).
- Welcome tests hold both launch-size centring and short-window scrolling, while
  the native configuration test protects the 1280 × 800 macOS launch frame
  (`test/presentation/welcome_view_test.dart:28-55`,
  `test/infrastructure/macos_window_configuration_test.dart:5-16`).
- Shelf tests hold the root-reorder state machine, expansion preservation,
  standalone adaptation, hover removal, and accessible arrange actions
  (`test/presentation/shelf_panel_test.dart:49-391`).
- Controller tests verify selection handoff, root-scoped links, and physical
  source adaptation between standalone and folder identities
  (`test/api/reader_controller_library_test.dart:77-231`).

## Architecture and documentation

`dependency_rules_test.dart` reads every import under `lib/`. Its data defines
the allowed rings, framework-free rings, and platform-only libraries
(`test/architecture/dependency_rules_test.dart:21-83`). Run it after any file
move or new dependency.

`docs_library_test.dart` opens `docs/` through Visual MD's own scanner and
builder. It checks shelf indexes, titles, links, anchors, placeholder text, and
source citation ranges (`test/docs/docs_library_test.dart:38-124`).
`tool/check_citations.py` adds an advisory semantic pass for citations whose
range still exists but no longer supports the prose.

`test/typography_measure_test.dart` is different: it prints measurements and
asserts nothing. Use it when researching a face or measure; durable invariants
belong in the focused typography tests
(`test/typography_measure_test.dart:19-78`).

## Project commands

The scripts under `bin/tools/` are the shared local and CI interface:

- `beautify.sh` formats authored Dart and Swift.
- `validate.sh` checks formatting and shell syntax, runs analysis and tests,
  checks documentation, and builds web plus the native target supported by the
  host.
- `beautipass.sh` formats first, then runs validation.

## Complete local check

```sh
bin/tools/validate.sh
```

The command checks canonical formatting, shell syntax, `flutter analyze`, the
complete test suite, documentation, and release builds. A host without a
configured native toolchain reports the skipped native check; CI exercises the
macOS path.

For a visible change, finish in the running app. A green build shows that the
renderer accepted the code; visual review shows whether the page and its
interaction still work for a reader. [Writing Docs](04-writing-docs.md)
describes the corresponding review loop for this library.
