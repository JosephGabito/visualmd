import 'package:flutter/material.dart' hide TableCell;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/api/render/document_view.dart';
import 'package:visualmd/api/render/inline_composer.dart';
import 'package:visualmd/api/render/reading_theme.dart';
import 'package:visualmd/api/theme/library_theme.dart';
import 'package:visualmd/api/theme/reading_measure.dart';
import 'package:visualmd/domain/reading/content/block.dart';
import 'package:visualmd/domain/reading/content/document_content.dart';
import 'package:visualmd/domain/reading/content/inline.dart';
import 'package:visualmd/infrastructure/markdown/markdown_document_parser.dart';
import 'package:visualmd/presentation/theme/built_in_themes.dart';
import 'package:visualmd/presentation/theme/hanging_punctuation.dart';
import 'package:visualmd/presentation/theme/reading_scale.dart';
import 'package:visualmd/presentation/theme/widow_binding.dart';

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

  ParagraphBlock para(String text) => ParagraphBlock([TextRun(text)]);
  const heading = HeadingBlock(
    level: 2,
    content: [TextRun('A section')],
    anchor: 'a-section',
  );

  Future<ReadingTheme?> pump(
    WidgetTester tester,
    List<Block> blocks, {
    ParagraphMarking marking = ParagraphMarking.spaced,
    double width = 900,
  }) async {
    ReadingTheme? theme;
    await tester.pumpWidget(
      MaterialApp(
        theme: libraryTheme(BuiltInThemes.paper),
        home: Scaffold(
          body: SizedBox(
            width: width,
            child: Builder(
              builder: (context) {
                theme = ReadingTheme.of(
                  context,
                  ReadingScale.comfortable.copyWith(marking: marking),
                );
                return DocumentView(
                  content: DocumentContent(blocks),
                  theme: theme!,
                  anchorKeys: {},
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return theme;
  }

  group('the rules, stated plainly', () {
    test('a paragraph is indented only when it follows another paragraph', () {
      expect(
        ParagraphRules.indents(para('before'), ParagraphMarking.indented),
        isTrue,
      );
      expect(
        ParagraphRules.indents(null, ParagraphMarking.indented),
        isFalse,
        reason: 'the opening paragraph has nothing to be separated from',
      );
      expect(
        ParagraphRules.indents(heading, ParagraphMarking.indented),
        isFalse,
        reason: 'nor has the one that opens a section',
      );
      expect(
        ParagraphRules.indents(
          const CodeBlock(code: 'x'),
          ParagraphMarking.indented,
        ),
        isFalse,
        reason:
            'a displayed block already left a space; indenting says it twice',
      );
    });

    test('a spaced setting never indents at all', () {
      expect(
        ParagraphRules.indents(para('before'), ParagraphMarking.spaced),
        isFalse,
      );
    });

    testWidgets('every external gap belongs to the block before it', (
      tester,
    ) async {
      final first = para('a');
      final second = para('b');
      final indented = await pump(tester, [
        first,
        second,
      ], marking: ParagraphMarking.indented);

      expect(
        indented!.spaceAfter(first, second),
        0,
        reason: 'an indent and a gap would say the same thing twice',
      );
      expect(
        indented.spaceAfter(first, heading),
        indented.blockGap,
        reason: 'a heading still needs separation from the prose before it',
      );
      expect(
        indented.spaceAfter(heading, second),
        indented.baseline / 2,
        reason: 'a heading binds more closely to what it introduces',
      );
      expect(
        indented.spaceAfter(second, null),
        0,
        reason: 'the final block must not leave an external trailing gap',
      );

      final spaced = await pump(tester, [first, second]);
      expect(
        spaced!.spaceAfter(first, second),
        spaced.baseline / 2,
        reason: 'a precise paragraph gap should not skip a full blank line',
      );
    });
  });

  testWidgets('one paragraph begins flush and leaves no trailing gap', (
    tester,
  ) async {
    final block = para(
      'A single paragraph follows the reading direction without inventing another edge.',
    );
    final theme = await pump(tester, [block]);
    final paragraph = tester.widget<Paragraph>(find.byType(Paragraph));
    final text = tester.widget<Text>(find.textContaining('single paragraph'));

    expect(paragraph.indent, 0);
    expect(text.textAlign, TextAlign.start);
    expect(text.softWrap, isTrue);
    expect(theme!.spaceAfter(block, null), 0);
  });

  testWidgets('each paragraph begins at the edge its language reads from', (
    tester,
  ) async {
    const arabic = '👩🏽‍💻 123 — العربية تبدأ من الحافة اليمنى.';
    await pump(tester, [para(arabic)]);

    final text = tester.widget<Text>(find.textContaining('العربية'));
    expect(text.textDirection, TextDirection.rtl);
    expect(text.textAlign, TextAlign.start);
    expect(text.textSpan!.toPlainText().replaceAll('\u00a0', ' '), arabic);
  });

  testWidgets('an RTL opening quote hangs from the reading edge', (
    tester,
  ) async {
    await pump(tester, [para('"العربية تبدأ بعلامة اقتباس.')]);

    final positioned = tester.widget<Positioned>(
      find.descendant(
        of: find.byType(Paragraph),
        matching: find.byType(Positioned),
      ),
    );
    expect(positioned.left, isNull);
    expect(positioned.right, lessThan(0));
    expect(find.text('“'), findsOneWidget);
  });

  testWidgets('CJK and emoji reflow without splitting their clusters', (
    tester,
  ) async {
    const source =
        '中文日本語沒有空格也需要自然換行，並保留👩🏽‍💻與👨‍👩‍👧‍👦完整顯示。'
        '這一段故意延長，以便在狹窄欄位中形成多行。';
    final theme = await pump(tester, [para(source)], width: 220);
    final richText = find.descendant(
      of: find.byType(Paragraph),
      matching: find.byType(RichText),
    );
    final widget = tester.widget<RichText>(richText);
    final size = tester.getSize(richText);

    expect(widget.text.toPlainText(), source);
    expect(size.width, lessThanOrEqualTo(220));
    expect(size.height, greaterThan(theme!.baseline * 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('indented paragraphs start further in, except the first', (
    tester,
  ) async {
    final theme = await pump(tester, [
      heading,
      para('First after the heading.'),
      para('Second one.'),
    ], marking: ParagraphMarking.indented);

    final paragraphs = tester
        .widgetList<Paragraph>(find.byType(Paragraph))
        .toList();
    expect(
      paragraphs.first.indent,
      0,
      reason: 'the paragraph opening a section is flush',
    );
    expect(paragraphs.last.indent, theme!.indent);

    // The indent is in the flow, so it moves the first line and nothing else.
    final indentBox = tester.widget<SizedBox>(
      find
          .descendant(
            of: find.byWidget(paragraphs.last),
            matching: find.byType(SizedBox),
          )
          .first,
    );
    expect(indentBox.width, theme.indent);
  });

  testWidgets('an indented column closes up; a spaced one does not', (
    tester,
  ) async {
    double gap(WidgetTester tester) =>
        tester.getTopLeft(find.textContaining('Second')).dy -
        tester.getBottomLeft(find.textContaining('First')).dy;

    final spacedTheme = await pump(tester, [
      para('First paragraph here.'),
      para('Second paragraph here.'),
    ]);
    final spaced = gap(tester);

    await pump(tester, [
      para('First paragraph here.'),
      para('Second paragraph here.'),
    ], marking: ParagraphMarking.indented);
    final indented = gap(tester);

    expect(spaced, closeTo(spacedTheme!.baseline / 2, 0.01));
    expect(indented, lessThan(4), reason: 'the column should be solid');
  });

  testWidgets('long prose reflows inside the measure and stays on its beat', (
    tester,
  ) async {
    const prose =
        'Long-form technical prose carries ordinary sentences alongside identifiers, version numbers, parenthetical qualifications, and links described in words. A reader may narrow the window or enlarge the shelf, but the paragraph must recompose into reachable lines instead of preserving accidental source wrapping or creating horizontal page overflow. Its line spacing remains deliberate from the first line to the last.';
    final block = para(prose);

    final wideTheme = await pump(tester, [block], width: 760);
    final wide = tester.getSize(find.textContaining('Long-form technical'));

    final narrowTheme = await pump(tester, [block], width: 340);
    final narrow = tester.getSize(find.textContaining('Long-form technical'));

    expect(narrow.width, lessThanOrEqualTo(340));
    expect(narrow.height, greaterThan(wide.height));
    expect(
      narrow.height / narrowTheme!.baseline,
      closeTo((narrow.height / narrowTheme.baseline).roundToDouble(), 0.01),
      reason: 'every recomposed line should keep the measured leading',
    );
    expect(wideTheme!.proseWidth(760), lessThanOrEqualTo(760));
    expect(tester.takeException(), isNull);
  });

  testWidgets('long emphasis reflows on the prose grid and stays accessible', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    const source =
        'This deliberately long emphasized passage continues through enough '
        'ordinary prose to wrap over several rendered lines without changing '
        'the measure, leading, searchability, selection, or baseline rhythm of '
        'the paragraph that contains it.';
    final block = const MarkdownDocumentParser()
        .parse('*$source*')
        .blocks
        .single;
    final theme = await pump(tester, [block], width: 340);
    final richText = find.descendant(
      of: find.byType(Paragraph),
      matching: find.byType(RichText),
    );
    final visible = tester.widget<RichText>(richText).text.toPlainText();
    final height = tester.getSize(richText).height;

    expect(visible.replaceAll('\u00a0', ' '), source);
    expect(height, greaterThan(theme!.baseline * 2));
    expect(
      height / theme.baseline,
      closeTo((height / theme.baseline).roundToDouble(), 0.01),
    );
    expect(tester.getSemantics(richText).label, visible);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('long strength reflows on the prose grid and stays accessible', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    const source =
        'This strongly important passage continues through enough ordinary '
        'prose to wrap over several rendered lines without changing the '
        'measure, leading, searchability, selection, or baseline rhythm of the '
        'paragraph that contains it.';
    final block = const MarkdownDocumentParser()
        .parse('**$source**')
        .blocks
        .single;
    final theme = await pump(tester, [block], width: 340);
    final richText = find.descendant(
      of: find.byType(Paragraph),
      matching: find.byType(RichText),
    );
    final visible = tester.widget<RichText>(richText).text.toPlainText();
    final height = tester.getSize(richText).height;

    expect(visible.replaceAll('\u00a0', ' '), source);
    expect(height, greaterThan(theme!.baseline * 2));
    expect(
      height / theme.baseline,
      closeTo((height / theme.baseline).roundToDouble(), 0.01),
    );
    expect(tester.getSemantics(richText).label, visible);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets(
    'editor wrapping is invisible at both narrow and wide reading measures',
    (tester) async {
      const parser = MarkdownDocumentParser();
      final wrapped = parser
          .parse(
            'A paragraph wrapped by an editor\n'
            'must compose from its words, not\n'
            'from those source lines. 中文源代码\n'
            '继续使用同一个自然段。',
          )
          .blocks
          .single;
      final unwrapped = parser
          .parse(
            'A paragraph wrapped by an editor must compose from its words, '
            'not from those source lines. 中文源代码继续使用同一个自然段。',
          )
          .blocks
          .single;

      Future<(Size, String)> layout(Block block, double width) async {
        await pump(tester, [block], width: width);
        final richText = find.descendant(
          of: find.byType(Paragraph),
          matching: find.byType(RichText),
        );
        final widget = tester.widget<RichText>(richText);
        return (tester.getSize(richText), widget.text.toPlainText());
      }

      for (final width in [340.0, 760.0]) {
        final wrappedLayout = await layout(wrapped, width);
        final unwrappedLayout = await layout(unwrapped, width);

        expect(wrappedLayout.$2, unwrappedLayout.$2);
        expect(wrappedLayout.$1, unwrappedLayout.$1);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('authored lines remain exact beats without paragraph spacing', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    const parser = MarkdownDocumentParser();
    final block = parser
        .parse(
          'First compact line.  \n'
          '    Second compact line.\\\n'
          'Last.',
        )
        .blocks
        .single;
    final theme = await pump(tester, [block], width: 760);
    final richText = find.descendant(
      of: find.byType(Paragraph),
      matching: find.byType(RichText),
    );
    final widget = tester.widget<RichText>(richText);
    final visible = widget.text.toPlainText();

    expect(visible, 'First compact line.\nSecond compact line.\nLast.');
    expect(
      visible,
      isNot(contains('\u00a0')),
      reason: 'widow binding must not rewrite across an authored line',
    );
    expect(
      tester.getSize(richText).height / theme!.baseline,
      closeTo(3, 0.01),
      reason: 'a hard break adds one line, not a paragraph gap',
    );
    expect(tester.getSemantics(richText).label, visible);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('paragraph marking follows prose into quotes and list items', (
    tester,
  ) async {
    final theme = await pump(tester, [
      QuoteBlock([para('Quote first.'), para('Quote second.')]),
      ListBlock(
        ordered: false,
        items: [
          ListItem([para('Item first.'), para('Item second.')]),
        ],
      ),
    ], marking: ParagraphMarking.indented);

    final paragraphs = tester
        .widgetList<Paragraph>(find.byType(Paragraph))
        .toList();
    expect(paragraphs.map((paragraph) => paragraph.indent), [
      0,
      theme!.indent,
      0,
      theme.indent,
    ]);

    double gap(String first, String second) =>
        tester.getTopLeft(find.textContaining(second)).dy -
        tester.getBottomLeft(find.textContaining(first)).dy;
    expect(gap('Quote first.', 'Quote second.'), lessThan(4));
    expect(gap('Item first.', 'Item second.'), lessThan(4));
  });

  testWidgets('the same forward gap is spent in every nested block sequence', (
    tester,
  ) async {
    final theme = await pump(tester, [
      para('Top first.'),
      para('Top second.'),
      QuoteBlock([para('Quote first.'), para('Quote second.')]),
      ListBlock(
        ordered: false,
        items: [
          ListItem([para('Item first.'), para('Item second.')]),
        ],
      ),
    ]);

    double gap(String first, String second) =>
        tester.getTopLeft(find.text(second)).dy -
        tester.getBottomLeft(find.text(first)).dy;

    for (final pair in [
      ('Top first.', 'Top second.'),
      ('Quote first.', 'Quote second.'),
      ('Item first.', 'Item second.'),
    ]) {
      expect(
        gap(pair.$1, pair.$2),
        closeTo(theme!.baseline / 2, 0.01),
        reason: '${pair.$1} owns the gap after it',
      );
    }
  });

  group('hanging punctuation', () {
    test('quotes hang whole; a dash carries ink and hangs halfway', () {
      expect(HangingPunctuation.fractionFor('“'), 1.0);
      expect(HangingPunctuation.fractionFor('—'), 0.5);
      expect(HangingPunctuation.hangs('T'), isFalse);
      expect(HangingPunctuation.hangs('('), isFalse);
    });

    test(
      'a mark is split off the front only when the line opens with plain text',
      () {
        const style = TextStyle();
        final (mark, rest) = Paragraph.splitHangingMark(const [
          TextSpan(text: '“Quoted,” she said.', style: style),
        ]);
        expect(mark, '“');
        expect((rest.single as TextSpan).text, 'Quoted,” she said.');

        final (none, _) = Paragraph.splitHangingMark(const [
          TextSpan(children: [TextSpan(text: '“emphasised')]),
        ]);
        expect(
          none,
          isNull,
          reason: 'pulling a marked run into the margin would move meaning',
        );
      },
    );

    testWidgets(
      'the text starts on the column edge and the mark sits outside it',
      (tester) async {
        final theme = await pump(tester, [
          para('Plain paragraph for the edge.'),
          para('“Quoted paragraph for the edge.'),
        ]);

        final plainEdge = tester
            .getTopLeft(find.textContaining('Plain paragraph'))
            .dx;
        final quotedEdge = tester
            .getTopLeft(find.textContaining('Quoted paragraph'))
            .dx;
        expect(
          quotedEdge,
          plainEdge,
          reason: 'the words line up, not the punctuation',
        );

        final markEdge = tester.getTopLeft(find.text('“')).dx;
        final expected = plainEdge - ReadingMeasure.widthOf('“', theme!.body);
        expect(
          markEdge,
          closeTo(expected, 0.5),
          reason: 'the mark hangs by its own width',
        );
      },
    );
  });

  group('widows', () {
    test('the last two words are bound so neither is left alone', () {
      final bound = WidowBinding.bind('one two three four five');
      expect(bound, 'one two three four five');
      expect(bound.split(' ').last, 'four five');
    });

    test('a short paragraph is left alone', () {
      expect(WidowBinding.bind('just three words'), 'just three words');
    });

    test('text that ends in a space is left as it is', () {
      expect(WidowBinding.bind('one two three four '), 'one two three four ');
    });

    testWidgets('a rendered paragraph carries the binding', (tester) async {
      await pump(tester, [
        para('A paragraph long enough to be worth binding at its end.'),
      ]);
      final text = tester.widget<Text>(find.textContaining('worth binding'));
      expect(text.textSpan!.toPlainText(), contains('its end.'));
    });

    test('the paragraph count crosses runs and preserves final emphasis', () {
      final bound = Paragraph.bindWidow(const [
        TextSpan(text: 'one two three '),
        TextSpan(
          children: [
            TextSpan(
              text: 'small tail',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ]);
      expect(
        bound.map((span) => span.toPlainText()).join(),
        'one two three small tail',
      );
      final wrapper = bound.last as TextSpan;
      expect(
        (wrapper.children!.single as TextSpan).style!.fontStyle,
        FontStyle.italic,
      );
    });

    test('a deliberate code ending is left byte-for-byte alone', () {
      final bound = Paragraph.bindWidow(const [
        TextSpan(text: 'one two three four five six '),
        InlineCodeSpan(
          text: 'small tail',
          style: TextStyle(fontFamily: 'Geist Mono'),
        ),
      ]);
      expect(
        bound.map((span) => span.toPlainText()).join(),
        'one two three four five six small tail',
      );
    });
  });
}
