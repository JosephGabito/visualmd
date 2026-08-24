import 'package:flutter/material.dart' hide TableCell;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/api/render/document_view.dart';
import 'package:visualmd/api/render/reading_theme.dart';
import 'package:visualmd/api/theme/library_theme.dart';
import 'package:visualmd/api/theme/reading_measure.dart';
import 'package:visualmd/api/widgets/code_block.dart';
import 'package:visualmd/domain/reading/content/block.dart';
import 'package:visualmd/domain/reading/content/document_content.dart';
import 'package:visualmd/domain/reading/content/inline.dart';
import 'package:visualmd/presentation/theme/built_in_themes.dart';
import 'package:visualmd/presentation/theme/reading_scale.dart';

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

  late Map<String, GlobalKey> keys;
  late ReadingTheme renderedTheme;

  Future<void> pumpDocument(
    WidgetTester tester,
    List<Block> blocks, {
    double width = 1100,
    TextScaler textScaler = TextScaler.noScaling,
  }) async {
    // Room for the measure: a narrow window clamps the column, which is its
    // own behaviour and not what these tests are about.
    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    keys = {};
    await tester.pumpWidget(
      MaterialApp(
        theme: libraryTheme(BuiltInThemes.paper),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: width,
              child: Builder(
                builder: (context) {
                  renderedTheme = ReadingTheme.of(
                    context,
                    ReadingScale.comfortable,
                  );
                  return DocumentView(
                    content: DocumentContent(blocks),
                    theme: renderedTheme,
                    anchorKeys: keys,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  ParagraphBlock paragraph(String text) => ParagraphBlock([TextRun(text)]);

  testWidgets('prose is held to the measure while code is given more room', (
    tester,
  ) async {
    await pumpDocument(tester, [
      paragraph('Some ordinary prose.'),
      const CodeBlock(code: 'final x = 1;'),
    ]);

    final proseWidth = tester.getSize(find.text('Some ordinary prose.')).width;
    final codeWidth = tester.getSize(find.byType(ReadableCodeBlock)).width;

    expect(
      codeWidth,
      greaterThan(proseWidth),
      reason: 'code is not prose and is not bound by the measure',
    );
  });

  testWidgets('every heading belongs more closely to what it introduces', (
    tester,
  ) async {
    final blocks = <Block>[];
    for (var level = 1; level <= 6; level++) {
      blocks
        ..add(paragraph('Before h$level.'))
        ..add(
          HeadingBlock(
            level: level,
            content: [TextRun('Heading h$level')],
            anchor: 'heading-h$level',
          ),
        )
        ..add(paragraph('After h$level.'));
    }
    await pumpDocument(tester, blocks);

    double gapBetween(String above, String below) =>
        tester.getTopLeft(find.text(below)).dy -
        tester.getBottomLeft(find.text(above)).dy;

    for (var level = 1; level <= 6; level++) {
      expect(
        gapBetween('Before h$level.', 'Heading h$level'),
        greaterThan(gapBetween('Heading h$level', 'After h$level.')),
        reason: 'h$level belongs to the text it introduces',
      );
    }
  });

  testWidgets('a multiline h1 uses display leading inside a reconciled block', (
    tester,
  ) async {
    const title =
        'A deliberately long level-one heading that wraps across several lines without turning each display line into a body-text beat';
    await pumpDocument(tester, [
      paragraph('Before.'),
      const HeadingBlock(
        level: 1,
        content: [TextRun(title)],
        anchor: 'long-title',
      ),
      paragraph('After.'),
    ], width: 430);

    final style = renderedTheme.heading(1);
    final rendered = tester.getSize(find.text(title));
    final lineHeight = style.fontSize! * style.height!;

    expect(rendered.height, greaterThan(lineHeight * 2));
    expect(
      style.height,
      lessThanOrEqualTo(1.15),
      reason: 'wrapped display lines should read as one heading',
    );
  });

  testWidgets('a scaled mixed-script heading returns prose to the beat', (
    tester,
  ) async {
    const title =
        'العربية والعناوين الطويلة — 日本語と中文 — remain complete when the reader enlarges the text';
    await pumpDocument(
      tester,
      [
        paragraph('Before.'),
        const HeadingBlock(
          level: 1,
          content: [TextRun(title)],
          anchor: 'mixed-script',
        ),
        paragraph('After.'),
      ],
      width: 430,
      textScaler: const TextScaler.linear(1.6),
    );

    final first = tester.getTopLeft(find.text('Before.')).dy;
    final after = tester.getTopLeft(find.text('After.')).dy;
    final beats = (after - first) / renderedTheme.baseline;

    expect(tester.takeException(), isNull);
    expect(
      (beats - beats.roundToDouble()).abs(),
      lessThan(0.02),
      reason: 'the shaped heading is reconciled after its real height is known',
    );
    expect(
      tester.getTopLeft(find.text('After.')).dy,
      greaterThan(tester.getBottomLeft(find.text(title)).dy),
    );
  });

  testWidgets('the running text returns on the beat after every departure', (
    tester,
  ) async {
    // Bringhurst's rule: whatever a heading, a list, a rule or a code block takes
    // vertically must come to a whole number of body lines, so the text after
    // it lands on the same rhythm as the text before it.
    ReadingTheme? theme;
    keys = {};
    tester.view.physicalSize = const Size(1600, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: libraryTheme(BuiltInThemes.paper),
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 1000,
              child: Builder(
                builder: (context) {
                  theme = ReadingTheme.of(context, ReadingScale.comfortable);
                  return DocumentView(
                    content: DocumentContent([
                      paragraph('First.'),
                      const HeadingBlock(
                        level: 2,
                        content: [TextRun('A section')],
                        anchor: 'a',
                      ),
                      paragraph('Second.'),
                      const CodeBlock(code: 'final x = 1;'),
                      paragraph('Third.'),
                      const RuleBlock(),
                      paragraph('Fourth.'),
                      ListBlock(
                        ordered: false,
                        items: [
                          ListItem([paragraph('First item.')]),
                          ListItem([paragraph('Second item.')]),
                        ],
                      ),
                      paragraph('Fifth.'),
                      const HeadingBlock(
                        level: 3,
                        content: [TextRun('Deeper')],
                        anchor: 'b',
                      ),
                      paragraph('Sixth.'),
                      const HeadingBlock(
                        level: 1,
                        content: [
                          TextRun(
                            'A multiline title whose natural display leading is reconciled only after the complete heading has been laid out',
                          ),
                        ],
                        anchor: 'multiline',
                      ),
                      paragraph('Seventh.'),
                    ]),
                    theme: theme!,
                    anchorKeys: keys,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final beat = theme!.baseline;
    final first = tester.getTopLeft(find.text('First.')).dy;
    for (final label in [
      'Second.',
      'Third.',
      'Fourth.',
      'Fifth.',
      'Sixth.',
      'Seventh.',
    ]) {
      final beats = (tester.getTopLeft(find.text(label)).dy - first) / beat;
      expect(
        (beats - beats.roundToDouble()).abs(),
        lessThan(0.02),
        reason:
            '$label sits ${beats.toStringAsFixed(3)} beats down, not a whole number',
      );
    }
  });

  testWidgets('a heading following a heading closes up', (tester) async {
    await pumpDocument(tester, [
      paragraph('Some text.'),
      const HeadingBlock(
        level: 1,
        content: [TextRun('Title')],
        anchor: 'title',
      ),
      const HeadingBlock(
        level: 2,
        content: [TextRun('Section')],
        anchor: 'section',
      ),
      paragraph('More text.'),
      const HeadingBlock(
        level: 2,
        content: [TextRun('Another')],
        anchor: 'another',
      ),
    ]);

    double gapBetween(String above, String below) =>
        tester.getTopLeft(find.text(below)).dy -
        tester.getBottomLeft(find.text(above)).dy;

    expect(
      gapBetween('Title', 'Section'),
      lessThan(gapBetween('More text.', 'Another')),
      reason: 'a title and its first subheading are one unit, with nothing between them',
    );
  });

  testWidgets('tone carries the hierarchy under size and weight', (
    tester,
  ) async {
    ReadingTheme? theme;
    await tester.pumpWidget(
      MaterialApp(
        theme: libraryTheme(BuiltInThemes.paper),
        home: Builder(
          builder: (context) {
            theme = ReadingTheme.of(context, ReadingScale.comfortable);
            return const SizedBox();
          },
        ),
      ),
    );

    double ink(Color c) => c.computeLuminance();
    final body = ink(theme!.body.color!);
    // On paper, more emphatic means darker, so luminance falls towards h1.
    expect(
      ink(theme!.heading(1).color!),
      lessThan(ink(theme!.heading(2).color!)),
    );
    expect(
      ink(theme!.heading(2).color!),
      lessThan(ink(theme!.heading(3).color!)),
    );
    expect(ink(theme!.heading(3).color!), lessThan(body));
    expect(
      ink(theme!.heading(4).color!),
      closeTo(body, 0.001),
      reason: 'h4 sits with the text',
    );
    expect(
      ink(theme!.heading(5).color!),
      greaterThan(body),
      reason: 'small headings recede',
    );
  });

  testWidgets('every heading can be found again by its anchor', (tester) async {
    await pumpDocument(tester, [
      const HeadingBlock(
        level: 1,
        content: [TextRun('Title')],
        anchor: 'title',
      ),
      const HeadingBlock(level: 2, content: [TextRun('Part')], anchor: 'part'),
    ]);

    expect(keys.keys, containsAll(['title', 'part']));
    expect(keys['part']!.currentContext, isNotNull);
  });

  testWidgets(
    'list markers hang in the margin, numbered from where the author started',
    (tester) async {
      await pumpDocument(tester, [
        ListBlock(
          ordered: true,
          start: 3,
          items: [
            ListItem([paragraph('third')]),
            ListItem([paragraph('fourth')]),
          ],
        ),
      ]);

      expect(find.text('3.'), findsOneWidget);
      expect(find.text('4.'), findsOneWidget);
      // The text of both items starts at the same place; the markers sit left of it.
      expect(
        tester.getTopLeft(find.text('third')).dx,
        tester.getTopLeft(find.text('fourth')).dx,
      );
      expect(
        tester.getTopLeft(find.text('3.')).dx,
        lessThan(tester.getTopLeft(find.text('third')).dx),
      );
    },
  );

  testWidgets('a task list shows what is done and what is not', (tester) async {
    await pumpDocument(tester, [
      ListBlock(
        ordered: false,
        items: [
          ListItem([paragraph('done')], checked: true),
          ListItem([paragraph('todo')], checked: false),
        ],
      ),
    ]);

    expect(find.byIcon(Icons.check_box_outlined), findsOneWidget);
    expect(find.byIcon(Icons.check_box_outline_blank), findsOneWidget);
  });

  testWidgets('a quotation is set one shade back, marked once by its rule', (
    tester,
  ) async {
    await pumpDocument(tester, [
      QuoteBlock([paragraph('Quoted matter.')]),
    ]);

    final text = tester.widget<Text>(find.text('Quoted matter.'));
    final style =
        text.textSpan!.style ??
        (text.textSpan! as TextSpan).children!.first.style!;
    expect(style.color, BuiltInThemes.paper.palette.muted);
    expect(
      style.fontStyle,
      isNot(FontStyle.italic),
      reason: 'italic is for emphasis, not for reading a paragraph in',
    );
  });

  testWidgets('a short table row is padded rather than collapsing the table', (
    tester,
  ) async {
    await pumpDocument(tester, [
      const TableBlock(
        head: [
          TableCell([TextRun('Key')]),
          TableCell([TextRun('Does')]),
        ],
        rows: [
          [
            TableCell([TextRun('only one')]),
          ],
        ],
      ),
    ]);

    expect(find.text('Key'), findsOneWidget);
    expect(find.text('only one'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('each table column follows its widest bounded cell and scrolls', (
    tester,
  ) async {
    const longValue =
        'A long explanatory value keeps enough characters on each line to '
        'read comfortably before it wraps inside the table cell.';
    await pumpDocument(tester, [
      const TableBlock(
        head: [
          TableCell([TextRun('ID')]),
          TableCell([TextRun('Explanation')]),
        ],
        rows: [
          [
            TableCell([TextRun('MAE1')]),
            TableCell([TextRun(longValue)]),
          ],
          [
            TableCell([TextRun('MAE2')]),
            TableCell([TextRun('Short note')]),
          ],
        ],
      ),
    ], width: 320);

    final context = tester.element(find.byType(DocumentView));
    final theme = ReadingTheme.of(context, ReadingScale.comfortable);
    final firstColumn = tester.getTopLeft(find.text('ID')).dx;
    final secondColumn = tester.getTopLeft(find.text('Explanation')).dx;
    final shortColumnWidth = secondColumn - firstColumn;
    final expectedShort = theme.minimumTableCellWidth('MAE1', theme.tableBody);

    expect(
      shortColumnWidth,
      closeTo(expectedShort, 0.5),
      reason: 'a short atomic column should stay as narrow as its widest value',
    );
    expect(
      shortColumnWidth,
      lessThan(
        ReadingMeasure.columnWidth(
          theme.tableBody,
          ReadingScale.minimumReadableMeasure,
          scaler: theme.textScaler,
        ),
      ),
      reason: 'short fields must not inherit the prose measure',
    );

    final tableWidth = tester.getSize(find.byType(Table)).width;
    final longColumnWidth = tableWidth - shortColumnWidth;
    final readableTextWidth = ReadingMeasure.columnWidth(
      theme.tableBody,
      ReadingScale.minimumReadableMeasure,
      scaler: theme.textScaler,
    );
    expect(
      longColumnWidth - theme.tableCellHorizontalPadding * 2,
      closeTo(readableTextWidth, 0.5),
      reason: 'long values wrap at the researched lower reading measure',
    );

    final horizontal = tester
        .widgetList<SingleChildScrollView>(find.byType(SingleChildScrollView))
        .singleWhere((view) => view.scrollDirection == Axis.horizontal);
    expect(
      horizontal.controller!.position.maxScrollExtent,
      greaterThan(0),
      reason: 'the table, not the surrounding document, owns overflow',
    );
    expect(
      tester
          .widgetList<Scrollbar>(find.byType(Scrollbar))
          .single
          .thumbVisibility,
      isTrue,
      reason: 'the reader needs a visible sign that more columns follow',
    );
  });
}
