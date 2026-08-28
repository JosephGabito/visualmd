import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/api/render/document_view.dart';
import 'package:visualmd/api/render/reading_theme.dart';
import 'package:visualmd/api/theme/library_theme.dart';
import 'package:visualmd/api/widgets/model_backed_selection_area.dart';
import 'package:visualmd/api/widgets/windowed_paragraph.dart';
import 'package:visualmd/domain/reading/content/block.dart';
import 'package:visualmd/domain/reading/content/document_content.dart';
import 'package:visualmd/domain/reading/content/inline.dart';
import 'package:visualmd/infrastructure/markdown/markdown_document_parser.dart';
import 'package:visualmd/presentation/theme/built_in_themes.dart';
import 'package:visualmd/presentation/theme/reading_scale.dart';

void main() {
  testWidgets(
    'an enormous provisional paragraph mounts one exact viewport window',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final source = _prose(100000);

      await tester.pumpWidget(_page(_content(source, revision: 1)));
      await tester.pumpAndSettle();

      expect(find.byType(WindowedProvisionalParagraph), findsOneWidget);
      expect(find.byType(Paragraph), findsNothing);
      final rendered = _renderedWindow();
      expect(rendered.length, lessThan(5000));
      expect(source.contains(rendered), isTrue);

      final window = tester.widget<WindowedProvisionalParagraph>(
        find.byType(WindowedProvisionalParagraph),
      );
      final size = tester.getSize(find.byType(WindowedProvisionalParagraph));
      final complete = TextPainter(
        text: TextSpan(text: source, style: window.style),
        textDirection: window.textDirection,
        textScaler: window.textScaler,
        strutStyle: window.strutStyle,
      )..layout(maxWidth: size.width);
      expect(size.height, closeTo(complete.height, 0.01));
      complete.dispose();

      expect(
        tester
            .widgetList<Semantics>(find.byType(Semantics))
            .any((widget) => widget.properties.label == source),
        isTrue,
      );

      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      position.jumpTo(position.maxScrollExtent * 0.5);
      await tester.pumpAndSettle();

      final middle = _renderedWindow();
      expect(middle.length, lessThan(5000));
      expect(source.contains(middle), isTrue);
      expect(middle, isNot(rendered));
    },
  );

  testWidgets('a proven append indexes only the old final line and suffix', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final first = _prose(40000);
    const suffix = ' One final streamed sentence arrives now.';
    final indexed = <int>[];
    final session = const MarkdownDocumentParser().startSession();
    final firstContent = session.append(first);
    final nextContent = session.append(suffix);

    await tester.pumpWidget(
      _page(firstContent, onSourceIndexed: indexed.add),
    );
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      _page(nextContent, onSourceIndexed: indexed.add),
    );
    await tester.pumpAndSettle();

    expect(indexed.length, 2);
    expect(indexed.first, greaterThanOrEqualTo(first.length));
    expect(indexed.last, lessThan(suffix.length + 256));
    expect(tester.takeException(), isNull);
  });
}

Widget _page(DocumentContent content, {ValueChanged<int>? onSourceIndexed}) =>
    MaterialApp(
      theme: libraryTheme(BuiltInThemes.paper),
      home: Scaffold(
        body: Builder(
          builder: (context) => ModelBackedSelectionArea(
            selectionIdentity: 'document',
            wholeText: () => readingTextOfBlocks(content.blocks, '\n\n'),
            child: CustomScrollView(
              slivers: [
                SliverDocumentView(
                  content: content,
                  theme: ReadingTheme.of(context, ReadingScale.comfortable),
                  anchorKeys: <String, GlobalKey>{},
                  debugOnParagraphCodeUnitsIndexed: onSourceIndexed,
                ),
              ],
            ),
          ),
        ),
      ),
    );

DocumentContent _content(
  String source, {
  required int revision,
  BlockTextAppend? append,
}) => DocumentContent.revisioned([
  DocumentBlock(
    id: const DocumentBlockId('provisional-paragraph'),
    revision: revision,
    commitment: BlockCommitment.provisional,
    block: ParagraphBlock([TextRun(source)]),
    textAppend: append,
  ),
], revision: revision);

String _prose(int characters) {
  const unit =
      'Generated prose keeps extending without an authored paragraph break. ';
  return (StringBuffer()
        ..writeAll(List.filled((characters / unit.length).ceil(), unit)))
      .toString()
      .substring(0, characters);
}

String _renderedWindow() => find
    .descendant(
      of: find.byKey(const ValueKey('paragraph-window')),
      matching: find.byType(RichText),
    )
    .evaluate()
    .map(
      (element) =>
          (element.renderObject! as RenderParagraph).text.toPlainText(),
    )
    .single;
