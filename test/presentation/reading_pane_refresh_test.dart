import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/api/render/document_view.dart';
import 'package:visualmd/api/theme/library_theme.dart';
import 'package:visualmd/api/widgets/reading_pane.dart';
import 'package:visualmd/application/use_cases/read_document.dart';
import 'package:visualmd/domain/library/document.dart';
import 'package:visualmd/domain/library/document_id.dart';
import 'package:visualmd/domain/library/library_root_id.dart';
import 'package:visualmd/domain/reading/content/block.dart';
import 'package:visualmd/domain/reading/content/document_content.dart';
import 'package:visualmd/domain/reading/content/inline.dart';
import 'package:visualmd/domain/reading/document_outline.dart';
import 'package:visualmd/infrastructure/markdown/markdown_document_parser.dart';
import 'package:visualmd/infrastructure/viewport/quiet_document_viewport_geometry.dart';
import 'package:visualmd/presentation/theme/built_in_themes.dart';
import 'package:visualmd/presentation/theme/reading_scale.dart';

void main() {
  const parser = MarkdownDocumentParser();
  final id = DocumentId(const LibraryRootId('notes'), 'guide.md');
  final body = List.generate(
    70,
    (index) => 'Paragraph $index has enough words to occupy the reading page.',
  ).join('\n\n');

  DocumentReading reading(String source) {
    final document = Document(id: id, content: source);
    return DocumentReading(
      document: document,
      source: source,
      outline: document.outline,
      content: parser.parse(source),
    );
  }

  Future<void> pump(WidgetTester tester, DocumentReading current, {Key? key}) =>
      tester.pumpWidget(
        MaterialApp(
          theme: libraryTheme(BuiltInThemes.paper),
          home: Scaffold(
            body: ReadingPane(
              key: key,
              reading: current,
              scale: ReadingScale.comfortable,
              viewportGeometry: const QuietDocumentViewportGeometryFactory(),
              onLink: (_) {},
              onActiveHeadingChanged: (_) {},
            ),
          ),
        ),
      );

  testWidgets(
    'refreshing the same document rebuilds its anchors without moving the reader',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final key = GlobalKey<ReadingPaneState>();
      await pump(tester, reading('# Opening\n\n$body'), key: key);
      await tester.pumpAndSettle();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
      await tester.pumpAndSettle();
      final scrollable = find.descendant(
        of: find.byType(CustomScrollView),
        matching: find.byType(Scrollable),
      );
      final before = tester.state<ScrollableState>(scrollable).position.pixels;
      expect(before, greaterThan(0));

      await pump(
        tester,
        reading('# Opening\n\n$body\n\n## Added by another process\n\nNew.'),
        key: key,
      );
      await tester.pumpAndSettle();
      final after = tester.state<ScrollableState>(scrollable).position.pixels;

      expect(after, closeTo(before, 0.01));
      key.currentState!.scrollToAnchor('added-by-another-process');
      await tester.pumpAndSettle();
      expect(find.text('Added by another process'), findsOneWidget);
    },
  );

  testWidgets('a fragment can reach an explicit custom HTML anchor', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey<ReadingPaneState>();
    final source =
        '''
# Opening

$body

<a name="appendix"></a>

## Appendix

Target.

$body
''';
    await tester.pumpWidget(
      MaterialApp(
        theme: libraryTheme(BuiltInThemes.paper),
        home: Scaffold(
          body: ReadingPane(
            key: key,
            reading: reading(source),
            scale: ReadingScale.comfortable,
            viewportGeometry: const QuietDocumentViewportGeometryFactory(),
            onLink: (_) {},
            onActiveHeadingChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final scrollable = find.descendant(
      of: find.byType(CustomScrollView),
      matching: find.byType(Scrollable),
    );
    final position = tester.state<ScrollableState>(scrollable).position;
    expect(position.pixels, 0);

    key.currentState!.scrollToAnchor('appendix');
    await tester.pumpAndSettle();

    expect(position.pixels, greaterThan(0));
    expect(tester.getTopLeft(find.text('Appendix')).dy, lessThan(80));
  });

  testWidgets('refresh replaces custom anchors for the same document', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey<ReadingPaneState>();

    Future<void> show(String source) => tester.pumpWidget(
      MaterialApp(
        theme: libraryTheme(BuiltInThemes.paper),
        home: Scaffold(
          body: ReadingPane(
            key: key,
            reading: reading(source),
            scale: ReadingScale.comfortable,
            viewportGeometry: const QuietDocumentViewportGeometryFactory(),
            onLink: (_) {},
            onActiveHeadingChanged: (_) {},
          ),
        ),
      ),
    );

    await show('# Opening\n\n<a name="old"></a>\n\n$body');
    await tester.pumpAndSettle();
    await show(
      '# Opening\n\n$body\n\n<a name="new"></a>\n\n## New target\n\n$body',
    );
    await tester.pumpAndSettle();

    final scrollable = find.descendant(
      of: find.byType(CustomScrollView),
      matching: find.byType(Scrollable),
    );
    final position = tester.state<ScrollableState>(scrollable).position;
    final before = position.pixels;

    key.currentState!.scrollToAnchor('old');
    await tester.pumpAndSettle();
    expect(position.pixels, closeTo(before, 0.01));

    key.currentState!.scrollToAnchor('new');
    await tester.pumpAndSettle();
    expect(position.pixels, greaterThan(before));
    expect(tester.getTopLeft(find.text('New target')).dy, lessThan(100));
  });

  testWidgets('a large document mounts the viewport rather than the corpus', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final source = List.generate(
      500,
      (index) =>
          'Paragraph $index has enough words to occupy the reading page.',
    ).join('\n\n');

    await pump(tester, reading(source));
    await tester.pumpAndSettle();

    final mounted = find.byType(Paragraph).evaluate().length;
    expect(mounted, greaterThan(0));
    expect(
      mounted,
      lessThan(40),
      reason: 'work must stay proportional to the viewport, not 500 blocks',
    );
  });

  testWidgets(
    'a revisioned tail append leaves the reader still and visits only the delta',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final key = GlobalKey<ReadingPaneState>();
      final initialContent = DocumentContent.revisioned([
        for (var index = 0; index < 500; index++)
          DocumentBlock(
            id: DocumentBlockId('paragraph-$index'),
            revision: 0,
            block: ParagraphBlock([
              TextRun(
                'Paragraph $index has enough words to occupy the reading page.',
              ),
            ]),
          ),
      ]);
      final tail = DocumentBlock(
        id: const DocumentBlockId('paragraph-500'),
        revision: 1,
        commitment: BlockCommitment.provisional,
        block: ParagraphBlock([TextRun('Streaming tail.')]),
      );
      final nextContent = initialContent.apply(
        DocumentMutation.append(
          baseRevision: 0,
          revision: 1,
          index: initialContent.entries.length,
          blocks: [tail],
        ),
      );
      final navigationPasses = <int>[];
      final renderPasses = <int>[];

      DocumentReading revision(DocumentContent content, String source) =>
          DocumentReading(
            document: Document(id: id, content: source),
            source: source,
            outline: DocumentOutline.parse(''),
            content: content,
          );

      Future<void> show(DocumentReading current) => tester.pumpWidget(
        MaterialApp(
          theme: libraryTheme(BuiltInThemes.paper),
          home: Scaffold(
            body: ReadingPane(
              key: key,
              reading: current,
              scale: ReadingScale.comfortable,
              viewportGeometry: const QuietDocumentViewportGeometryFactory(),
              onLink: (_) {},
              onActiveHeadingChanged: (_) {},
              debugOnNavigationBlocksIndexed: navigationPasses.add,
              debugOnRenderBlocksIndexed: renderPasses.add,
            ),
          ),
        ),
      );

      await show(revision(initialContent, 'revision 0'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1000));
      await tester.pumpAndSettle();
      final scrollable = find.descendant(
        of: find.byType(CustomScrollView),
        matching: find.byType(Scrollable),
      );
      final position = tester.state<ScrollableState>(scrollable).position;
      final before = position.pixels;

      await show(revision(nextContent, 'revision 1'));
      await tester.pumpAndSettle();

      expect(position.pixels, closeTo(before, 0.01));
      expect(navigationPasses, [500, 1]);
      expect(renderPasses, [500, 1]);
      expect(find.text('Streaming tail.'), findsNothing);
    },
  );

  testWidgets(
    'a provisional tail replacement leaves the reader still and visits only its suffix',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final initialContent = DocumentContent.revisioned([
        for (var index = 0; index < 500; index++)
          DocumentBlock(
            id: DocumentBlockId('paragraph-$index'),
            revision: 0,
            block: ParagraphBlock([
              TextRun(
                'Paragraph $index has enough words to occupy the reading page.',
              ),
            ]),
          ),
        DocumentBlock(
          id: const DocumentBlockId('provisional'),
          revision: 0,
          commitment: BlockCommitment.provisional,
          block: ParagraphBlock([TextRun('Unfinished tail.')]),
        ),
      ]);
      final nextContent = initialContent.apply(
        DocumentMutation(
          baseRevision: 0,
          revision: 1,
          operations: [
            ReplaceBlocks(
              index: 500,
              removeCount: 1,
              blocks: [
                DocumentBlock(
                  id: const DocumentBlockId('final-500'),
                  revision: 1,
                  block: ParagraphBlock([TextRun('Finished tail.')]),
                ),
                DocumentBlock(
                  id: const DocumentBlockId('final-501'),
                  revision: 1,
                  commitment: BlockCommitment.provisional,
                  block: ParagraphBlock([TextRun('Next provisional block.')]),
                ),
              ],
            ),
          ],
        ),
      );
      final navigationPasses = <int>[];
      final renderPasses = <int>[];

      DocumentReading revision(DocumentContent content) => DocumentReading(
        document: Document(id: id, content: 'revision ${content.revision}'),
        source: 'revision ${content.revision}',
        outline: DocumentOutline.parse(''),
        content: content,
      );

      Future<void> show(DocumentContent content) => tester.pumpWidget(
        MaterialApp(
          theme: libraryTheme(BuiltInThemes.paper),
          home: Scaffold(
            body: ReadingPane(
              reading: revision(content),
              scale: ReadingScale.comfortable,
              viewportGeometry: const QuietDocumentViewportGeometryFactory(),
              onLink: (_) {},
              onActiveHeadingChanged: (_) {},
              debugOnNavigationBlocksIndexed: navigationPasses.add,
              debugOnRenderBlocksIndexed: renderPasses.add,
            ),
          ),
        ),
      );

      await show(initialContent);
      await tester.pumpAndSettle();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1000));
      await tester.pumpAndSettle();
      final scrollable = find.descendant(
        of: find.byType(CustomScrollView),
        matching: find.byType(Scrollable),
      );
      final position = tester.state<ScrollableState>(scrollable).position;
      final before = position.pixels;

      await show(nextContent);
      await tester.pumpAndSettle();

      expect(position.pixels, closeTo(before, 0.01));
      expect(navigationPasses, [501, 2]);
      expect(renderPasses, [501, 2]);
    },
  );

  testWidgets('a revised block above the viewport cannot move its anchor', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey<ReadingPaneState>();
    final initialContent = DocumentContent.revisioned([
      for (var index = 0; index < 200; index++)
        DocumentBlock(
          id: DocumentBlockId('stable-$index'),
          revision: 0,
          block: ParagraphBlock([TextRun('Stable paragraph $index.')]),
        ),
    ]);
    final nextContent = initialContent.apply(
      DocumentMutation(
        baseRevision: 0,
        revision: 1,
        operations: [
          ReplaceBlocks(
            index: 0,
            removeCount: 1,
            blocks: [
              DocumentBlock(
                id: const DocumentBlockId('stable-0'),
                revision: 1,
                block: ParagraphBlock([
                  TextRun(
                    List.filled(80, 'Expanded provisional text.').join(' '),
                  ),
                ]),
              ),
            ],
          ),
        ],
      ),
    );

    DocumentReading revision(DocumentContent content) => DocumentReading(
      document: Document(id: id, content: 'revision ${content.revision}'),
      source: 'revision ${content.revision}',
      outline: DocumentOutline.parse(''),
      content: content,
    );

    Future<void> show(DocumentContent content) => tester.pumpWidget(
      MaterialApp(
        theme: libraryTheme(BuiltInThemes.paper),
        home: Scaffold(
          body: ReadingPane(
            key: key,
            reading: revision(content),
            scale: ReadingScale.comfortable,
            viewportGeometry: const QuietDocumentViewportGeometryFactory(),
            onLink: (_) {},
            onActiveHeadingChanged: (_) {},
          ),
        ),
      ),
    );

    await show(initialContent);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1500));
    await tester.pumpAndSettle();
    final scrollable = find.descendant(
      of: find.byType(CustomScrollView),
      matching: find.byType(Scrollable),
    );
    final position = tester.state<ScrollableState>(scrollable).position;
    final beforePixels = position.pixels;
    final target = [
      for (var index = 1; index < 200; index++)
        if (find.text('Stable paragraph $index.').evaluate().isNotEmpty) index,
    ].first;
    final targetFinder = find.text('Stable paragraph $target.');
    final beforeTop = tester.getTopLeft(targetFinder).dy;

    await show(nextContent);
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(targetFinder).dy, closeTo(beforeTop, 0.01));
    expect(position.pixels, greaterThan(beforePixels));
  });

  testWidgets('a reader already following the tail remains pinned to it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey<ReadingPaneState>();
    final initialContent = DocumentContent.revisioned([
      for (var index = 0; index < 100; index++)
        DocumentBlock(
          id: DocumentBlockId('tail-$index'),
          revision: 0,
          block: ParagraphBlock([
            TextRun('Paragraph $index keeps enough room in the document.'),
          ]),
        ),
    ]);
    final nextContent = initialContent.apply(
      DocumentMutation.append(
        baseRevision: 0,
        revision: 1,
        index: initialContent.entries.length,
        blocks: [
          DocumentBlock(
            id: DocumentBlockId('tail-100'),
            revision: 1,
            commitment: BlockCommitment.provisional,
            block: ParagraphBlock([
              TextRun(
                'The streamed tail is deliberately long enough to create a '
                'new final line and a larger maximum scroll extent.',
              ),
            ]),
          ),
        ],
      ),
    );

    DocumentReading revision(DocumentContent content) => DocumentReading(
      document: Document(id: id, content: 'revision ${content.revision}'),
      source: 'revision ${content.revision}',
      outline: DocumentOutline.parse(''),
      content: content,
    );

    Future<void> show(DocumentContent content) => tester.pumpWidget(
      MaterialApp(
        theme: libraryTheme(BuiltInThemes.paper),
        home: Scaffold(
          body: ReadingPane(
            key: key,
            reading: revision(content),
            scale: ReadingScale.comfortable,
            viewportGeometry: const QuietDocumentViewportGeometryFactory(),
            onLink: (_) {},
            onActiveHeadingChanged: (_) {},
          ),
        ),
      ),
    );

    await show(initialContent);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -100000));
    await tester.pumpAndSettle();
    final scrollable = find.descendant(
      of: find.byType(CustomScrollView),
      matching: find.byType(Scrollable),
    );
    final position = tester.state<ScrollableState>(scrollable).position;
    expect(position.pixels, closeTo(position.maxScrollExtent, 0.01));
    final oldMaximum = position.maxScrollExtent;

    await show(nextContent);
    await tester.pumpAndSettle();

    expect(position.maxScrollExtent, greaterThan(oldMaximum));
    expect(position.pixels, closeTo(position.maxScrollExtent, 0.01));
  });

  testWidgets('a distant heading materializes before its exact alignment', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey<ReadingPaneState>();
    final middle = List.generate(
      500,
      (index) =>
          'Paragraph $index has enough words to occupy the reading page.',
    ).join('\n\n');

    final tail = List.generate(
      20,
      (index) => 'Following paragraph $index keeps room below the target.',
    ).join('\n\n');
    await pump(
      tester,
      reading('# Opening\n\n$middle\n\n## Distant target\n\nArrived.\n\n$tail'),
      key: key,
    );
    await tester.pumpAndSettle();
    expect(find.text('Distant target'), findsNothing);

    key.currentState!.scrollToAnchor('distant-target');
    await tester.pumpAndSettle();

    expect(find.text('Distant target'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Distant target')).dy, lessThan(80));
  });
}
