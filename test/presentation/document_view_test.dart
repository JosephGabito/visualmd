import 'package:flutter/material.dart' hide TableCell;
import 'package:flutter/semantics.dart';
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

Iterable<SemanticsNode> semanticsDescendants(SemanticsNode node) sync* {
  final children = <SemanticsNode>[];
  node.visitChildren((child) {
    children.add(child);
    return true;
  });
  for (final child in children) {
    yield child;
    yield* semanticsDescendants(child);
  }
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

  testWidgets('an image placeholder owns its full height in the document', (
    tester,
  ) async {
    final imageKey = GlobalKey();
    final followingKey = GlobalKey();
    const style = TextStyle(fontSize: 18, height: 1.5);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Paragraph(
                spans: [
                  WidgetSpan(
                    child: SizedBox(key: imageKey, width: 180, height: 180),
                  ),
                ],
                style: style,
                strut: StrutStyle.fromTextStyle(style, forceStrutHeight: true),
              ),
              SizedBox(key: followingKey, height: 20),
            ],
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byKey(imageKey)), const Size(180, 180));
    expect(
      tester.getTopLeft(find.byKey(followingKey)).dy,
      greaterThanOrEqualTo(tester.getBottomLeft(find.byKey(imageKey)).dy),
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

  testWidgets('every heading level wraps as one complete display block', (
    tester,
  ) async {
    for (var level = 1; level <= 6; level++) {
      final title =
          'Level $level has a deliberately long heading that must occupy several rendered lines at a narrow measure without clipping, widening the page, or losing its place in the hierarchy';
      await pumpDocument(tester, [
        HeadingBlock(
          level: level,
          content: [TextRun(title)],
          anchor: 'level-$level',
        ),
        paragraph('After level $level.'),
      ], width: 340);

      final style = renderedTheme.heading(level);
      final rendered = tester.getSize(find.text(title));
      expect(
        rendered.height,
        greaterThan(style.fontSize! * style.height! * 1.5),
        reason: 'h$level should prove its multiline geometry',
      );
      expect(rendered.width, lessThanOrEqualTo(340));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('mixed-direction and unbreakable headings remain reachable', (
    tester,
  ) async {
    const arabic =
        'العربية والعناوين الطويلة تحتاج إلى التفاف صحيح دون أن تختفي الكلمات من الصفحة';
    const unbreakable =
        'VisualMdWorkspaceDocumentRootAbsolutePathWithoutAnyBreakOpportunityAndWithEnoughCharactersToCrossSeveralNarrowLines';
    await pumpDocument(tester, [
      const HeadingBlock(
        level: 2,
        content: [TextRun(arabic)],
        anchor: 'arabic',
      ),
      const HeadingBlock(
        level: 4,
        content: [TextRun(unbreakable)],
        anchor: 'unbreakable',
      ),
      paragraph('Still here.'),
    ], width: 340);

    expect(tester.getSize(find.text(arabic)).width, lessThanOrEqualTo(340));
    expect(
      tester.widget<Text>(find.text(arabic)).textDirection,
      TextDirection.rtl,
    );
    expect(
      tester.getSize(find.text(unbreakable)).width,
      lessThanOrEqualTo(340),
    );
    expect(
      tester.widget<Text>(find.text(unbreakable)).textDirection,
      TextDirection.ltr,
    );
    expect(find.text('Still here.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('assistive technology receives every authored heading level', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpDocument(tester, [
      for (var level = 1; level <= 6; level++)
        HeadingBlock(
          level: level,
          content: [TextRun('Semantic heading $level')],
          anchor: 'semantic-$level',
        ),
    ]);

    for (var level = 1; level <= 6; level++) {
      final node = tester.getSemantics(find.text('Semantic heading $level'));
      expect(node.flagsCollection.isHeader, isTrue);
      expect(node.headingLevel, level);
    }
    semantics.dispose();
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
                      const TableBlock(
                        head: [
                          TableCell([TextRun('Metric')]),
                          TableCell([TextRun('Value')]),
                        ],
                        rows: [
                          [
                            TableCell([TextRun('Revenue')]),
                            TableCell([TextRun('1,234.50')]),
                          ],
                        ],
                      ),
                      paragraph('After table.'),
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
      'After table.',
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

  testWidgets('a thematic break is one quiet, structural beat', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpDocument(tester, [
      paragraph('Before the change of subject.'),
      const RuleBlock(),
      paragraph('After the change of subject.'),
    ]);

    final rule = find.bySemanticsLabel('Thematic break');
    expect(rule, findsOneWidget);
    expect(tester.getSize(rule).height, closeTo(renderedTheme.baseline, 0.01));

    final divider = tester.widget<Divider>(find.byType(Divider));
    expect(divider.thickness, 1);
    expect(divider.color, renderedTheme.palette.border);
    expect(
      tester.getSize(find.byType(Divider)).width,
      closeTo(renderedTheme.proseWidth(1100), 0.01),
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
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

  testWidgets('tight lists compact their gaps without tightening prose', (
    tester,
  ) async {
    const wrapped =
        'A deliberately long list item wraps across several lines while keeping the same body leading as prose outside the container.';
    await pumpDocument(tester, [
      paragraph('Running prose.'),
      ListBlock(
        ordered: false,
        items: [
          ListItem([paragraph(wrapped)]),
          ListItem([paragraph('Second item.')]),
        ],
      ),
    ], width: 360);

    final paragraphs = find.byType(Paragraph);
    final prose = tester.widget<Paragraph>(paragraphs.at(0));
    final item = tester.widget<Paragraph>(paragraphs.at(1));
    final firstItem = tester.getTopLeft(paragraphs.at(1)).dy;
    final secondItem = tester.getTopLeft(paragraphs.at(2)).dy;

    expect(item.style.height, prose.style.height);
    expect(item.strut, prose.strut);
    expect(
      secondItem - firstItem,
      closeTo(tester.getSize(paragraphs.at(1)).height, 0.5),
      reason: 'a tight list adds no gap after its wrapped item',
    );
  });

  testWidgets('loose lists spend half a beat between items', (tester) async {
    await pumpDocument(tester, [
      ListBlock(
        ordered: false,
        loose: true,
        items: [
          ListItem([paragraph('First loose item.')]),
          ListItem([paragraph('Second loose item.')]),
        ],
      ),
    ]);

    final first = tester.getTopLeft(find.text('First loose item.')).dy;
    final second = tester.getTopLeft(find.text('Second loose item.')).dy;
    expect(
      second - first,
      closeTo(renderedTheme.baseline + renderedTheme.containerGap, 0.5),
    );
  });

  testWidgets('an already-whole container never acquires a phantom beat', (
    tester,
  ) async {
    await pumpDocument(tester, [
      ListBlock(
        ordered: true,
        items: [
          ListItem([paragraph('First.')]),
          ListItem([paragraph('Second.')]),
        ],
      ),
      ListBlock(
        ordered: true,
        items: [
          ListItem([paragraph('Third.')]),
        ],
      ),
    ]);

    final second = tester.getTopLeft(find.text('Second.')).dy;
    final third = tester.getTopLeft(find.text('Third.')).dy;
    expect(
      third - second,
      closeTo(renderedTheme.baseline * 2, 0.5),
      reason: 'one final item line plus one root-level block gap',
    );
  });

  testWidgets('wide markers grow their gutter without moving item text', (
    tester,
  ) async {
    await pumpDocument(tester, [
      ListBlock(
        ordered: true,
        start: 999999,
        items: [
          ListItem([paragraph('A wide first marker.')]),
          ListItem([paragraph('The next item keeps the established edge.')]),
        ],
      ),
    ], width: 420);

    final marker = find.text('999999.');
    final firstText = find.byType(Paragraph).at(0);
    final secondText = find.byType(Paragraph).at(1);

    expect(tester.getSize(marker).height, closeTo(renderedTheme.baseline, 0.5));
    expect(
      tester.getTopRight(marker).dx,
      lessThan(tester.getTopLeft(firstText).dx),
    );
    expect(
      tester.getTopLeft(firstText).dx,
      closeTo(tester.getTopLeft(secondText).dx, 0.5),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('nested containers return following prose to the body grid', (
    tester,
  ) async {
    await pumpDocument(tester, [
      paragraph('Before.'),
      QuoteBlock([
        paragraph('Quoted first paragraph.'),
        ListBlock(
          ordered: false,
          loose: true,
          items: [
            ListItem([paragraph('First nested item.')]),
            ListItem([
              paragraph('Second nested item.'),
              QuoteBlock([paragraph('A quotation inside the list.')]),
            ]),
          ],
        ),
      ]),
      paragraph('After.'),
    ], width: 430);

    final before = tester.getTopLeft(find.text('Before.')).dy;
    final after = tester.getTopLeft(find.text('After.')).dy;
    final beats = (after - before) / renderedTheme.baseline;
    expect((beats - beats.round()).abs(), lessThan(0.02));
    expect(tester.takeException(), isNull);
  });

  testWidgets('only the outermost list reconciles a nested tree', (
    tester,
  ) async {
    await pumpDocument(tester, [
      ListBlock(
        ordered: false,
        loose: true,
        items: [
          ListItem([
            paragraph('Parent.'),
            ListBlock(
              ordered: false,
              loose: true,
              items: [
                ListItem([paragraph('First child.')]),
                ListItem([
                  paragraph('Second child.'),
                  ListBlock(
                    ordered: false,
                    loose: true,
                    items: [
                      ListItem([paragraph('First grandchild.')]),
                      ListItem([paragraph('Second grandchild.')]),
                    ],
                  ),
                ]),
              ],
            ),
          ]),
        ],
      ),
      paragraph('Following prose.'),
    ]);

    final parent = tester.getTopLeft(find.text('Parent.')).dy;
    final following = tester.getTopLeft(find.text('Following prose.')).dy;
    expect(
      following - parent,
      closeTo(renderedTheme.baseline * 8, 0.5),
      reason: 'five prose lines, four half-beat relationships and one root gap',
    );
  });

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
    expect(find.bySemanticsLabel('Completed task'), findsOneWidget);
    expect(find.bySemanticsLabel('Incomplete task'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('done')).dx -
          tester.getTopRight(find.byIcon(Icons.check_box_outlined)).dx,
      closeTo(renderedTheme.em * 0.5, 0.5),
      reason: 'the marker gutter remains visible between icon and label',
    );
  });

  testWidgets('an RTL list hangs its marker from the reading edge', (
    tester,
  ) async {
    await pumpDocument(tester, [
      ListBlock(
        ordered: true,
        items: [
          ListItem([paragraph('البند الأول')]),
        ],
      ),
    ]);

    expect(
      tester.getCenter(find.text('1.')).dx,
      greaterThan(tester.getCenter(find.text('البند الأول')).dx),
    );
    expect(
      tester.widget<Text>(find.text('البند الأول')).textDirection,
      TextDirection.rtl,
    );
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

  testWidgets('a quotation rule follows the authored reading edge', (
    tester,
  ) async {
    await pumpDocument(tester, [
      QuoteBlock([paragraph('العربية تبدأ من اليمين')]),
    ]);

    final decorated = tester
        .widgetList<Container>(find.byType(Container))
        .where(
          (container) =>
              container.decoration is BoxDecoration &&
              (container.decoration! as BoxDecoration).border
                  is BorderDirectional,
        )
        .single;
    final border =
        (decorated.decoration! as BoxDecoration).border! as BorderDirectional;
    final directionality = tester.widget<Directionality>(
      find
          .ancestor(
            of: find.byWidget(decorated),
            matching: find.byType(Directionality),
          )
          .first,
    );

    expect(border.start.style, BorderStyle.solid);
    expect(directionality.textDirection, TextDirection.rtl);
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

  testWidgets('a header-only one-column table remains visible', (tester) async {
    await pumpDocument(tester, [
      const TableBlock(
        head: [
          TableCell([TextRun('Only column')]),
        ],
        rows: [],
      ),
    ]);

    expect(find.byType(Table), findsOneWidget);
    expect(find.text('Only column'), findsOneWidget);
    expect(tester.getSize(find.byType(Table)).height, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('table cells keep the alignment the author assigned', (
    tester,
  ) async {
    await pumpDocument(tester, [
      const TableBlock(
        head: [
          TableCell([TextRun('Left')]),
          TableCell([TextRun('Center')], alignment: ColumnAlignment.center),
          TableCell([TextRun('Right')], alignment: ColumnAlignment.right),
        ],
        rows: [
          [
            TableCell([TextRun('العربية')]),
            TableCell([
              TextRun('center value'),
            ], alignment: ColumnAlignment.center),
            TableCell([
              TextRun('right value'),
            ], alignment: ColumnAlignment.right),
          ],
        ],
      ),
    ]);

    expect(tester.widget<Text>(find.text('العربية')).textAlign, TextAlign.left);
    expect(
      tester.widget<Text>(find.text('center value')).textAlign,
      TextAlign.center,
    );
    expect(
      tester.widget<Text>(find.text('right value')).textAlign,
      TextAlign.right,
    );
  });

  testWidgets('each table cell keeps its own reading direction', (
    tester,
  ) async {
    await pumpDocument(tester, [
      const TableBlock(
        head: [
          TableCell([TextRun('Language')]),
        ],
        rows: [
          [
            TableCell([TextRun('العربية 123')]),
          ],
        ],
      ),
    ]);

    expect(
      tester.widget<Text>(find.text('العربية 123')).textDirection,
      TextDirection.rtl,
    );
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

  testWidgets('many extremely uneven columns overflow only inside the table', (
    tester,
  ) async {
    const longValue =
        'This deliberately long research note must retain a readable local '
        'measure while nine short identifier columns remain compact.';
    await pumpDocument(tester, [
      TableBlock(
        head: [
          for (var column = 1; column <= 10; column++)
            TableCell([TextRun('C$column')]),
        ],
        rows: [
          [
            for (var column = 1; column < 10; column++)
              TableCell([TextRun('$column')]),
            const TableCell([TextRun(longValue)]),
          ],
        ],
      ),
    ], width: 360);

    final horizontal = tester
        .widgetList<SingleChildScrollView>(find.byType(SingleChildScrollView))
        .singleWhere((view) => view.scrollDirection == Axis.horizontal);
    expect(horizontal.controller!.position.maxScrollExtent, greaterThan(0));
    expect(tester.getSize(find.byType(DocumentView)).width, 360);
    expect(
      tester.getSize(find.byType(Table)).width,
      greaterThan(tester.getSize(find.byType(DocumentView)).width),
      reason: 'the two-dimensional shape belongs to the local scroller',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('table numbers use tabular lining figures and expose structure', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpDocument(tester, [
      const TableBlock(
        head: [
          TableCell([TextRun('Metric')]),
          TableCell([TextRun('Value')]),
        ],
        rows: [
          [
            TableCell([TextRun('Revenue')]),
            TableCell([TextRun('1,234.50')]),
          ],
        ],
      ),
    ]);

    final numeric = tester.widget<Text>(find.text('1,234.50'));
    final numericSpan =
        (numeric.textSpan! as TextSpan).children!.single as TextSpan;
    expect(
      numericSpan.style!.fontFeatures,
      containsAll(const [
        FontFeature.liningFigures(),
        FontFeature.tabularFigures(),
      ]),
      reason: 'columns compare quantities by position, not prose figures',
    );
    final table = tester.getSemantics(find.byType(Table));
    final tableRoles = semanticsDescendants(table).map((node) => node.role);
    expect(table.role, SemanticsRole.table);
    expect(tableRoles, contains(SemanticsRole.row));
    expect(
      tester.getSemantics(find.text('Metric')).role,
      SemanticsRole.columnHeader,
    );
    expect(tableRoles, contains(SemanticsRole.cell));

    semantics.dispose();
  });

  testWidgets('a shaped table returns enlarged prose to the body grid', (
    tester,
  ) async {
    const longValue =
        'A sufficiently long cell wraps onto several compact table lines so '
        'the surface height must be measured after layout, not predicted.';
    await pumpDocument(
      tester,
      [
        paragraph('Before table.'),
        const TableBlock(
          head: [
            TableCell([TextRun('Metric')]),
            TableCell([TextRun('Explanation')]),
          ],
          rows: [
            [
              TableCell([TextRun('MAE')]),
              TableCell([TextRun(longValue)]),
            ],
          ],
        ),
        paragraph('After shaped table.'),
      ],
      width: 440,
      textScaler: const TextScaler.linear(1.45),
    );

    final before = tester.getTopLeft(find.text('Before table.')).dy;
    final after = tester.getTopLeft(find.text('After shaped table.')).dy;
    final beats = (after - before) / renderedTheme.baseline;
    expect(
      (beats - beats.roundToDouble()).abs(),
      lessThan(0.02),
      reason: 'the complete shaped surface and its outgoing gap reconcile',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a nested table returns both local and outer prose to phase', (
    tester,
  ) async {
    await pumpDocument(tester, [
      paragraph('Before container.'),
      ListBlock(
        ordered: false,
        loose: true,
        items: [
          ListItem([
            const TableBlock(
              head: [
                TableCell([TextRun('Metric')]),
                TableCell([TextRun('Value')]),
              ],
              rows: [
                [
                  TableCell([TextRun('Revenue')]),
                  TableCell([TextRun('1,234.50')]),
                ],
              ],
            ),
            paragraph('After nested table.'),
          ]),
        ],
      ),
      paragraph('After container.'),
    ]);

    final nestedAfter = tester.getTopLeft(find.text('After nested table.')).dy;
    final outerBefore = tester.getTopLeft(find.text('Before container.')).dy;
    final outerAfter = tester.getTopLeft(find.text('After container.')).dy;

    for (final distance in [
      nestedAfter - outerBefore,
      outerAfter - outerBefore,
    ]) {
      final beats = distance / renderedTheme.baseline;
      expect(
        (beats - beats.roundToDouble()).abs(),
        lessThan(0.02),
        reason:
            'each reading scope must hand its following prose back in phase',
      );
    }
    expect(tester.takeException(), isNull);
  });
}
