import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/api/theme/library_theme.dart';
import 'package:visualmd/api/widgets/reading_pane.dart';
import 'package:visualmd/application/use_cases/read_document.dart';
import 'package:visualmd/domain/library/document.dart';
import 'package:visualmd/domain/library/document_id.dart';
import 'package:visualmd/domain/library/library_root_id.dart';
import 'package:visualmd/infrastructure/markdown/markdown_document_parser.dart';
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

  Future<void> pump(WidgetTester tester, DocumentReading current) =>
      tester.pumpWidget(
        MaterialApp(
          theme: libraryTheme(BuiltInThemes.paper),
          home: Scaffold(
            body: ReadingPane(
              reading: current,
              scale: ReadingScale.comfortable,
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
      await pump(tester, reading('# Opening\n\n$body'));
      await tester.pumpAndSettle();

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -900),
      );
      await tester.pumpAndSettle();
      final scrollable = find.descendant(
        of: find.byType(SingleChildScrollView),
        matching: find.byType(Scrollable),
      );
      final before = tester.state<ScrollableState>(scrollable).position.pixels;
      expect(before, greaterThan(0));

      await pump(
        tester,
        reading('# Opening\n\n$body\n\n## Added by another process\n\nNew.'),
      );
      await tester.pumpAndSettle();
      final after = tester.state<ScrollableState>(scrollable).position.pixels;

      expect(after, closeTo(before, 0.01));
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
            onLink: (_) {},
            onActiveHeadingChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final scrollable = find.descendant(
      of: find.byType(SingleChildScrollView),
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
      of: find.byType(SingleChildScrollView),
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
}
