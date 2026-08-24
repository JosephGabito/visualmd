import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/api/reader_controller.dart';
import 'package:visualmd/api/screens/reader_screen.dart';
import 'package:visualmd/api/theme/library_theme.dart';
import 'package:visualmd/application/ports/folder_scanner.dart';
import 'package:visualmd/application/ports/markdown_scanner.dart';
import 'package:visualmd/application/library_mutation_queue.dart';
import 'package:visualmd/application/use_cases/add_folder.dart';
import 'package:visualmd/application/use_cases/add_markdown.dart';
import 'package:visualmd/application/use_cases/move_folder.dart';
import 'package:visualmd/application/use_cases/read_document.dart';
import 'package:visualmd/application/use_cases/remove_folder.dart';
import 'package:visualmd/application/use_cases/remove_markdown.dart';
import 'package:visualmd/application/use_cases/search_documents.dart';
import 'package:visualmd/domain/library/library_builder.dart';
import 'package:visualmd/infrastructure/markdown/markdown_document_parser.dart';
import 'package:visualmd/infrastructure/memory/in_memory_library_repository.dart';
import 'package:visualmd/infrastructure/search/literal_document_search.dart';
import 'package:visualmd/presentation/theme/built_in_themes.dart';
import 'package:visualmd/presentation/theme/reading_scale.dart';
import 'package:visualmd/presentation/theme/theme_registry.dart';

final class _Scanner implements FolderScanner {
  @override
  Future<ScannedFolder> scan(FolderRef ref) async => const ScannedFolder(
    name: 'notes',
    files: [FileEntry('README.md', '# Notes\n\nA paragraph to set.\n')],
  );
}

final class _MarkdownScanner implements MarkdownScanner {
  @override
  Future<ScannedMarkdown> scan(MarkdownRef ref) =>
      throw MarkdownUnavailable(ref);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    for (final entry in {
      'Alegreya': 'assets/fonts/Alegreya.ttf',
      'Literata': 'assets/fonts/Literata.ttf',
      'Inter': 'assets/fonts/Inter.ttf',
      'Geist Mono': 'assets/fonts/GeistMono.ttf',
    }.entries) {
      await (FontLoader(
        entry.key,
      )..addFont(rootBundle.load(entry.value))).load();
    }
  });

  late List<(String, String)> saved;

  Future<ReaderController> controller({ReadingScale? scale}) async {
    saved = [];
    final repository = InMemoryLibraryRepository();
    final mutations = LibraryMutationQueue();
    const parser = MarkdownDocumentParser();
    final c = ReaderController(
      addFolder: AddFolder(
        scanner: _Scanner(),
        repository: repository,
        mutations: mutations,
      ),
      addMarkdown: AddMarkdown(
        scanner: _MarkdownScanner(),
        repository: repository,
        mutations: mutations,
      ),
      removeFolder: RemoveFolder(repository: repository, mutations: mutations),
      removeMarkdown: RemoveMarkdown(
        repository: repository,
        mutations: mutations,
      ),
      moveFolder: MoveFolder(repository: repository, mutations: mutations),
      readDocument: ReadDocument(repository: repository, parser: parser),
      searchDocuments: SearchDocuments(
        repository: repository,
        search: LiteralDocumentSearch(parser: parser),
      ),
      pickFolder: () async => null,
      sampleFolder: const FolderRef(id: 'sample', name: 'notes'),
      themes: ThemeRegistry(),
      readingScale: scale,
      savePreference: (key, value) async => saved.add((key, value)),
    );
    await c.openSampleLibrary();
    return c;
  }

  group('choosing a text size', () {
    test('steps up and down through the offered sizes', () async {
      final c = await controller();
      expect(c.readingScale.base, 18);

      await c.enlargeText();
      expect(c.readingScale.base, 19);
      await c.shrinkText();
      await c.shrinkText();
      expect(c.readingScale.base, 17);

      await c.resetText();
      expect(c.readingScale.base, 18);
    });

    test('stops at the ends rather than running off them', () async {
      final c = await controller();
      for (var i = 0; i < 20; i++) {
        await c.enlargeText();
      }
      expect(c.readingScale.base, ReadingScale.sizes.last);
      for (var i = 0; i < 20; i++) {
        await c.shrinkText();
      }
      expect(c.readingScale.base, ReadingScale.sizes.first);
    });

    test('is remembered, and read back', () async {
      final c = await controller();
      await c.enlargeText();
      expect(saved, [(textSizePreference, '19.0')]);
      expect(ReadingScale.fromStoredBase('19.0').base, 19);
    });

    test(
      'an unreadable stored size falls back rather than refusing to open',
      () {
        expect(ReadingScale.fromStoredBase(null), ReadingScale.comfortable);
        expect(
          ReadingScale.fromStoredBase('enormous'),
          ReadingScale.comfortable,
        );
        expect(ReadingScale.fromStoredBase('999'), ReadingScale.comfortable);
      },
    );
  });

  testWidgets('the column grows with the text, so the measure holds', (
    tester,
  ) async {
    // A window with room for the measure: on a narrow one the column is
    // clamped by what is left between the panels, which is its own behaviour.
    tester.view.physicalSize = const Size(2400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final c = await controller();
    await tester.pumpWidget(
      MaterialApp(
        theme: libraryTheme(BuiltInThemes.paper),
        home: ReaderScreen(controller: c, openExternal: (_) {}),
      ),
    );
    await tester.pumpAndSettle();

    // The paragraph fills its column, so its width is the measure's width.
    // Matched loosely: the last two words are bound with a non-breaking
    // space, so the rendered text is not the source text.
    double columnWidth() =>
        tester.getSize(find.textContaining('A paragraph').first).width;

    final atDefault = columnWidth();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
    await tester.sendKeyEvent(LogicalKeyboardKey.equal);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
    await tester.pumpAndSettle();

    expect(c.readingScale.base, 19, reason: '⌘= enlarges');
    expect(
      columnWidth(),
      greaterThan(atDefault),
      reason: 'a larger face needs a wider column to hold the same measure',
    );
  });
}
