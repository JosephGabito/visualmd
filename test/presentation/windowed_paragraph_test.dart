import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/api/render/document_view.dart';
import 'package:visualmd/api/render/reading_theme.dart';
import 'package:visualmd/api/theme/library_theme.dart';
import 'package:visualmd/api/widgets/model_backed_selection_area.dart';
import 'package:visualmd/api/widgets/windowed_paragraph.dart';
import 'package:visualmd/api/widgets/windowed_rich_paragraph.dart';
import 'package:visualmd/domain/reading/content/block.dart';
import 'package:visualmd/domain/reading/content/document_content.dart';
import 'package:visualmd/domain/reading/content/inline.dart';
import 'package:visualmd/infrastructure/markdown/markdown_document_parser.dart';
import 'package:visualmd/presentation/theme/built_in_themes.dart';
import 'package:visualmd/presentation/theme/reading_scale.dart';
import 'package:visualmd/presentation/theme/typographic_punctuation.dart';
import 'package:visualmd/presentation/theme/widow_binding.dart';

void main() {
  testWidgets(
    'initial wrap work stays bounded and publishes complete geometry once',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final source = _prose(1000000);
      final steps = <int>[];

      await tester.pumpWidget(
        _page(
          _content(source, revision: 1),
          onInitialIndexStep: (codeUnits, _) => steps.add(codeUnits),
        ),
      );

      expect(find.byKey(const ValueKey('paragraph-indexing')), findsOneWidget);
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      final unpublishedExtent = position.maxScrollExtent;
      var frames = 0;
      while (find
          .byKey(const ValueKey('paragraph-indexing'))
          .evaluate()
          .isNotEmpty) {
        expect(position.maxScrollExtent, unpublishedExtent);
        await tester.pump(const Duration(milliseconds: 1));
        frames++;
        expect(frames, lessThan(400));
      }

      expect(frames, isPositive);
      expect(steps.length, greaterThan(1));
      expect(steps, everyElement(lessThan(5000)));
      expect(position.maxScrollExtent, greaterThan(unpublishedExtent));
      expect(find.byKey(const ValueKey('paragraph-window')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'an unproven replacement retains old geometry until the new index is exact',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final indexed = <int>[];
      final initial = _prose(100000);
      final replacement = _prose(1000000);

      await tester.pumpWidget(
        _page(_content(initial, revision: 1), onSourceIndexed: indexed.add),
      );
      await tester.pumpAndSettle();
      ScrollPosition position() =>
          tester.state<ScrollableState>(find.byType(Scrollable).first).position;
      final oldExtent = position().maxScrollExtent;
      final oldHeight = tester
          .getSize(find.byType(WindowedPlainParagraph))
          .height;
      final retained = find.byType(WindowedPlainParagraph).evaluate().single;
      expect(indexed, hasLength(1));

      await tester.pumpWidget(
        _page(_content(replacement, revision: 2), onSourceIndexed: indexed.add),
      );
      expect(find.byKey(const ValueKey('paragraph-indexing')), findsNothing);
      expect(
        identical(
          find.byType(WindowedPlainParagraph).evaluate().single,
          retained,
        ),
        isTrue,
      );

      var frames = 0;
      while (indexed.length == 1) {
        expect(
          tester.getSize(find.byType(WindowedPlainParagraph)).height,
          oldHeight,
        );
        await tester.pump(const Duration(milliseconds: 1));
        frames++;
        expect(frames, lessThan(400));
      }
      await tester.pumpAndSettle();

      expect(
        tester.getSize(find.byType(WindowedPlainParagraph)).height,
        greaterThan(oldHeight),
      );
      expect(position().maxScrollExtent, greaterThan(oldExtent));
      expect(indexed, [initial.length, replacement.length]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'an enormous provisional paragraph mounts one exact viewport window',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final source = _prose(100000);

      await tester.pumpWidget(_page(_content(source, revision: 1)));
      await tester.pumpAndSettle();

      expect(find.byType(WindowedPlainParagraph), findsOneWidget);
      expect(find.byType(Paragraph), findsNothing);
      final rendered = _renderedWindow();
      expect(rendered.length, lessThan(5000));
      expect(source.contains(rendered), isTrue);

      final window = tester.widget<WindowedPlainParagraph>(
        find.byType(WindowedPlainParagraph),
      );
      final size = tester.getSize(find.byType(WindowedPlainParagraph));
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

  testWidgets(
    'bounded projection matches eager shaping for bidi text and emoji',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final source = List.filled(
        1200,
        'قال الكاتب "انتظر..." 😀 -- ואז אמר "כן". ',
      ).join();

      await tester.pumpWidget(_page(_content(source, revision: 1)));
      await tester.pumpAndSettle();

      final window = tester.widget<WindowedPlainParagraph>(
        find.byType(WindowedPlainParagraph),
      );
      expect(window.textDirection, TextDirection.rtl);
      final size = tester.getSize(find.byType(WindowedPlainParagraph));
      final expected = TypographicProjection.of(source).text;
      final complete = TextPainter(
        text: TextSpan(text: expected, style: window.style),
        textDirection: window.textDirection,
        textScaler: window.textScaler,
        strutStyle: window.strutStyle,
      )..layout(maxWidth: size.width);
      expect(size.height, closeTo(complete.height, 0.01));
      complete.dispose();

      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      position.jumpTo(position.maxScrollExtent * 0.5);
      await tester.pumpAndSettle();
      expect(expected, contains(_renderedWindow()));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a rich atomic paragraph mounts only its styled viewport range', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final rich = _richParagraph(800);

    await tester.pumpWidget(_page(_richContent(rich, revision: 1)));
    expect(
      find.byKey(const ValueKey('rich-paragraph-indexing')),
      findsOneWidget,
    );
    await tester.pumpAndSettle();

    expect(find.byType(WindowedRichParagraph), findsOneWidget);
    expect(find.byType(WindowedPlainParagraph), findsOneWidget);
    expect(find.byType(Paragraph), findsNothing);
    final rendered = _renderedWindow();
    expect(rendered.length, lessThan(5000));
    expect(rendered, contains('“quoted…”'));
    expect(rendered, contains('"HEAD"...'));

    final window = tester.widget<WindowedRichParagraph>(
      find.byType(WindowedRichParagraph),
    );
    final inner = tester.widget<WindowedPlainParagraph>(
      find.byType(WindowedPlainParagraph),
    );
    expect(inner.overscanLines, 0);
    final size = tester.getSize(find.byType(WindowedRichParagraph));
    final complete = TextPainter(
      text: TextSpan(
        style: window.style,
        children: window.composer.compose(rich.content, style: window.style),
      ),
      textDirection: inner.textDirection,
      textScaler: window.textScaler,
      strutStyle: window.strutStyle,
    )..layout(maxWidth: size.width);
    expect(size.height, closeTo(complete.height, 0.01));
    complete.dispose();

    final position = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    position.jumpTo(position.maxScrollExtent * 0.5);
    await tester.pumpAndSettle();
    expect(_renderedWindow(), isNot(rendered));
    expect(_renderedWindow().length, lessThan(5000));
    final viewportRect = tester.getRect(find.byType(CustomScrollView));
    final windowRect = tester.getRect(
      find.byKey(const ValueKey('paragraph-window')),
    );
    expect(windowRect.top, lessThanOrEqualTo(viewportRect.top));
    expect(windowRect.bottom, greaterThanOrEqualTo(viewportRect.bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a rich replacement cannot walk the scrollbar through partial geometry',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final indexed = <int>[];
      final initial = _richParagraph(800);
      final replacement = _richParagraph(4000);

      await tester.pumpWidget(
        _page(_richContent(initial, revision: 1), onSourceIndexed: indexed.add),
      );
      await tester.pumpAndSettle();
      ScrollPosition position() =>
          tester.state<ScrollableState>(find.byType(Scrollable).first).position;
      final oldExtent = position().maxScrollExtent;
      final oldHeight = tester
          .getSize(find.byType(WindowedPlainParagraph))
          .height;
      final oldWindow = _renderedWindow();
      final retained = find.byType(WindowedPlainParagraph).evaluate().single;
      expect(indexed, hasLength(1));

      await tester.pumpWidget(
        _page(
          _richContent(replacement, revision: 2),
          onSourceIndexed: indexed.add,
        ),
      );
      expect(
        find.byKey(const ValueKey('rich-paragraph-indexing')),
        findsNothing,
      );
      expect(
        identical(
          find.byType(WindowedPlainParagraph).evaluate().single,
          retained,
        ),
        isTrue,
      );

      var frames = 0;
      while (indexed.length == 1) {
        expect(
          tester.getSize(find.byType(WindowedPlainParagraph)).height,
          oldHeight,
        );
        expect(position().maxScrollExtent, oldExtent);
        expect(_renderedWindow(), oldWindow);
        await tester.pump(const Duration(milliseconds: 1));
        frames++;
        expect(frames, lessThan(400));
      }
      await tester.pumpAndSettle();

      expect(
        tester.getSize(find.byType(WindowedPlainParagraph)).height,
        greaterThan(oldHeight),
      );
      expect(position().maxScrollExtent, greaterThan(oldExtent));
      expect(indexed, [initial.text.length, replacement.text.length]);
      expect(tester.takeException(), isNull);
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

    await tester.pumpWidget(_page(firstContent, onSourceIndexed: indexed.add));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_page(nextContent, onSourceIndexed: indexed.add));
    await tester.pumpAndSettle();

    expect(indexed.length, 2);
    expect(indexed.first, greaterThanOrEqualTo(first.length));
    expect(indexed.last, lessThan(suffix.length + 256));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'an append may complete punctuation without revisiting its prefix',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final first = '${_prose(40000)} The author said "wait--';
      const suffix = '- then..." before continuing.';
      final indexed = <int>[];
      final session = const MarkdownDocumentParser().startSession();

      await tester.pumpWidget(
        _page(session.append(first), onSourceIndexed: indexed.add),
      );
      await tester.pumpAndSettle();
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      position.jumpTo(position.maxScrollExtent * 0.5);
      await tester.pumpAndSettle();
      final pixels = position.pixels;

      await tester.pumpWidget(
        _page(session.append(suffix), onSourceIndexed: indexed.add),
      );
      await tester.pumpAndSettle();

      final nextPosition = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      expect(nextPosition.pixels, pixels);
      expect(indexed.last, lessThan(suffix.length + 256));
      nextPosition.jumpTo(nextPosition.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(
        _renderedWindow(),
        endsWith('The author said “wait— then…” before continuing.'),
      );

      final window = tester.widget<WindowedPlainParagraph>(
        find.byType(WindowedPlainParagraph),
      );
      final size = tester.getSize(find.byType(WindowedPlainParagraph));
      final expected = TypographicProjection.of('$first$suffix').text;
      final complete = TextPainter(
        text: TextSpan(text: expected, style: window.style),
        textDirection: window.textDirection,
        textScaler: window.textScaler,
        strutStyle: window.strutStyle,
      )..layout(maxWidth: size.width);
      expect(size.height, closeTo(complete.height, 0.01));
      complete.dispose();
    },
  );

  testWidgets(
    'safe finalization retains the window and reflows only its widow tail',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final source = _prose(100000);
      final indexed = <int>[];
      final session = const MarkdownDocumentParser().startSession();
      final provisional = session.append(source);

      await tester.pumpWidget(_page(provisional, onSourceIndexed: indexed.add));
      await tester.pumpAndSettle();
      final retained = find.byType(WindowedPlainParagraph).evaluate().single;
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      position.jumpTo(position.maxScrollExtent * 0.5);
      await tester.pumpAndSettle();
      final pixels = position.pixels;

      await tester.pumpWidget(
        _page(session.finish(), onSourceIndexed: indexed.add),
      );
      await tester.pumpAndSettle();

      expect(find.byType(WindowedPlainParagraph), findsOneWidget);
      expect(
        identical(
          find.byType(WindowedPlainParagraph).evaluate().single,
          retained,
        ),
        isTrue,
      );
      expect(position.pixels, pixels);
      expect(indexed.length, 2);
      expect(indexed.last, lessThan(512));

      final window = tester.widget<WindowedPlainParagraph>(
        find.byType(WindowedPlainParagraph),
      );
      final size = tester.getSize(find.byType(WindowedPlainParagraph));
      final complete = TextPainter(
        text: TextSpan(text: WidowBinding.bind(source), style: window.style),
        textDirection: window.textDirection,
        textScaler: window.textScaler,
        strutStyle: window.strutStyle,
      )..layout(maxWidth: size.width);
      expect(size.height, closeTo(complete.height, 0.01));
      complete.dispose();
    },
  );

  testWidgets('punctuation stays windowed and exact through finalization', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final source = List.filled(
      1800,
      'The author said "wait..." before the next generated sentence. ',
    ).join();
    final session = const MarkdownDocumentParser().startSession();

    await tester.pumpWidget(_page(session.append(source)));
    await tester.pumpAndSettle();
    expect(find.byType(WindowedPlainParagraph), findsOneWidget);
    expect(_renderedWindow(), contains('“wait…”'));
    final retained = find.byType(WindowedPlainParagraph).evaluate().single;
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    position.jumpTo(position.maxScrollExtent * 0.5);
    await tester.pumpAndSettle();
    final pixels = position.pixels;

    await tester.pumpWidget(_page(session.finish()));
    await tester.pumpAndSettle();

    expect(find.byType(WindowedPlainParagraph), findsOneWidget);
    expect(
      identical(
        find.byType(WindowedPlainParagraph).evaluate().single,
        retained,
      ),
      isTrue,
    );
    expect(position.pixels, pixels);
    expect(_renderedWindow(), contains('“wait…”'));

    final window = tester.widget<WindowedPlainParagraph>(
      find.byType(WindowedPlainParagraph),
    );
    final size = tester.getSize(find.byType(WindowedPlainParagraph));
    final expected = TypographicProjection.of(WidowBinding.bind(source)).text;
    final complete = TextPainter(
      text: TextSpan(text: expected, style: window.style),
      textDirection: window.textDirection,
      textScaler: window.textScaler,
      strutStyle: window.strutStyle,
    )..layout(maxWidth: size.width);
    expect(size.height, closeTo(complete.height, 0.01));
    complete.dispose();
  });
}

Widget _page(
  DocumentContent content, {
  ValueChanged<int>? onSourceIndexed,
  ParagraphIndexStepObserver? onInitialIndexStep,
}) => MaterialApp(
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
              debugOnParagraphInitialIndexStep: onInitialIndexStep,
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

DocumentContent _richContent(
  ParagraphBlock paragraph, {
  required int revision,
}) => DocumentContent.revisioned([
  DocumentBlock(
    id: const DocumentBlockId('provisional-rich-paragraph'),
    revision: revision,
    commitment: BlockCommitment.provisional,
    block: paragraph,
  ),
], revision: revision);

ParagraphBlock _richParagraph(int repetitions) {
  const unit = <Inline>[
    TextRun('Generated '),
    MarkedRun(InlineMark.strong, [TextRun('bold')]),
    TextRun(' prose said "quoted..." with '),
    CodeRun('"HEAD"...'),
    TextRun(' and '),
    LinkRun(href: '/guide', children: [TextRun('a link')]),
    TextRun(' before continuing. '),
  ];
  return ParagraphBlock([
    for (var index = 0; index < repetitions; index++) ...unit,
  ]);
}

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
