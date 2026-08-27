import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/api/render/document_view.dart';
import 'package:visualmd/api/render/reading_theme.dart';
import 'package:visualmd/api/theme/library_theme.dart';
import 'package:visualmd/domain/reading/content/block.dart';
import 'package:visualmd/domain/reading/content/document_content.dart';
import 'package:visualmd/domain/reading/content/inline.dart';
import 'package:visualmd/presentation/theme/built_in_themes.dart';
import 'package:visualmd/presentation/theme/reading_scale.dart';

DocumentBlock paragraph(String id, String text, {int revision = 0}) =>
    DocumentBlock(
      id: DocumentBlockId(id),
      revision: revision,
      block: ParagraphBlock([TextRun(text)]),
    );

void main() {
  testWidgets(
    'a tail append indexes only its delta and retains mounted state',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final initial = DocumentContent.revisioned([
        for (var index = 0; index < 500; index++)
          paragraph(
            'paragraph-$index',
            'Paragraph $index has enough words to occupy the reading page.',
          ),
      ]);
      final appended = paragraph(
        'paragraph-500',
        'Appended tail.',
        revision: 1,
      );
      final next = initial.apply(
        DocumentMutation.append(
          baseRevision: 0,
          revision: 1,
          index: initial.entries.length,
          blocks: [appended],
        ),
      );
      final indexed = <int>[];
      final anchorKeys = <String, GlobalKey>{};

      Future<void> show(DocumentContent content) => tester.pumpWidget(
        MaterialApp(
          theme: libraryTheme(BuiltInThemes.paper),
          home: Scaffold(
            body: Builder(
              builder: (context) => CustomScrollView(
                slivers: [
                  SliverDocumentView(
                    content: content,
                    theme: ReadingTheme.of(context, ReadingScale.comfortable),
                    anchorKeys: anchorKeys,
                    debugOnBlocksIndexed: indexed.add,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await show(initial);
      await tester.pumpAndSettle();
      final firstElement = find.textContaining('Paragraph 0').evaluate().single;
      expect(find.byType(Paragraph).evaluate(), hasLength(lessThan(40)));

      await show(next);
      await tester.pumpAndSettle();

      expect(indexed, [500, 1]);
      expect(
        identical(
          find.textContaining('Paragraph 0').evaluate().single,
          firstElement,
        ),
        isTrue,
      );
      expect(find.text('Appended tail.'), findsNothing);
    },
  );
}
