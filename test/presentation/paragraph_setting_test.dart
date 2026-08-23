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
      'JetBrains Mono': 'assets/fonts/JetBrainsMono.ttf',
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
  }) async {
    ReadingTheme? theme;
    await tester.pumpWidget(
      MaterialApp(
        theme: libraryTheme(BuiltInThemes.paper),
        home: Scaffold(
          body: SizedBox(
            width: 900,
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

    test(
      'an indented column is solid: the indent and a gap are one signal twice',
      () {
        expect(
          ParagraphRules.separates(
            para('a'),
            para('b'),
            ParagraphMarking.indented,
          ),
          isFalse,
        );
        expect(
          ParagraphRules.separates(
            para('a'),
            para('b'),
            ParagraphMarking.spaced,
          ),
          isTrue,
        );
        expect(
          ParagraphRules.separates(
            para('a'),
            heading,
            ParagraphMarking.indented,
          ),
          isTrue,
          reason: 'a heading still needs its air',
        );
      },
    );
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

    await pump(tester, [
      para('First paragraph here.'),
      para('Second paragraph here.'),
    ]);
    final spaced = gap(tester);

    await pump(tester, [
      para('First paragraph here.'),
      para('Second paragraph here.'),
    ], marking: ParagraphMarking.indented);
    final indented = gap(tester);

    expect(indented, lessThan(spaced));
    expect(indented, lessThan(4), reason: 'the column should be solid');
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
          style: TextStyle(fontFamily: 'JetBrains Mono'),
        ),
      ]);
      expect(
        bound.map((span) => span.toPlainText()).join(),
        'one two three four five six small tail',
      );
    });
  });
}
