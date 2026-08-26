import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/api/render/document_view.dart';
import 'package:visualmd/api/render/inline_composer.dart';
import 'package:visualmd/api/render/reading_theme.dart';
import 'package:visualmd/api/theme/font_metrics.dart';
import 'package:visualmd/api/theme/library_theme.dart';
import 'package:visualmd/api/widgets/document_image.dart';
import 'package:visualmd/application/ports/document_image_loader.dart';
import 'package:visualmd/domain/library/document_id.dart';
import 'package:visualmd/domain/library/library_root_id.dart';
import 'package:visualmd/domain/reading/content/block.dart';
import 'package:visualmd/domain/reading/content/inline.dart';
import 'package:visualmd/domain/search/search_result.dart';
import 'package:visualmd/infrastructure/markdown/markdown_document_parser.dart';
import 'package:visualmd/presentation/theme/built_in_themes.dart';
import 'package:visualmd/presentation/theme/reading_scale.dart';
import 'package:visualmd/presentation/theme/theme_palette.dart';

final class _MissingImageLoader implements DocumentImageLoader {
  const _MissingImageLoader();

  @override
  Future<Uint8List?> load(DocumentId document, String source) async => null;
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

  late InlineComposer composer;
  late ReadingTheme theme;
  final tapped = <String>[];

  Future<void> makeComposer(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: libraryTheme(BuiltInThemes.paper),
        home: Builder(
          builder: (context) {
            theme = ReadingTheme.of(context, ReadingScale.comfortable);
            composer = InlineComposer(theme: theme, onTapLink: tapped.add);
            return const SizedBox();
          },
        ),
      ),
    );
  }

  /// The text of everything composed, as the reader would see it.
  String rendered(List<Inline> runs) {
    final out = StringBuffer();
    void walk(InlineSpan span) {
      if (span is TextSpan) {
        if (span.text != null) out.write(span.text);
        span.children?.forEach(walk);
      }
    }

    composer.compose(runs).forEach(walk);
    return out.toString();
  }

  testWidgets('quotes are set as the marks they stand for', (tester) async {
    await makeComposer(tester);
    expect(
      rendered([const TextRun('He said "hello" softly.')]),
      'He said “hello” softly.',
    );
    expect(
      rendered([const TextRun("It's a dog's life.")]),
      'It’s a dog’s life.',
    );
    expect(rendered([const TextRun('("quoted")')]), '(“quoted”)');
  });

  testWidgets('hyphens and dots become dashes and an ellipsis', (tester) async {
    await makeComposer(tester);
    expect(rendered([const TextRun('pages 1--10')]), 'pages 1–10');
    expect(
      rendered([const TextRun('a thought --- interrupted')]),
      'a thought — interrupted',
    );
    expect(rendered([const TextRun('and so on...')]), 'and so on…');
    expect(rendered([const TextRun('well-known')]), 'well-known');
    expect(rendered([const TextRun('---"hello"')]), '—“hello”');
  });

  testWidgets(
    'escaping changes Markdown grammar without adding a visual signal',
    (tester) async {
      await makeComposer(tester);
      final paragraph =
          const MarkdownDocumentParser()
                  .parse(r'\*literal\*, \"quoted\", and an ellipsis\...')
                  .blocks
                  .single
              as ParagraphBlock;

      expect(paragraph.content, everyElement(isA<TextRun>()));
      expect(
        rendered(paragraph.content),
        '*literal*, “quoted”, and an ellipsis…',
      );
    },
  );

  testWidgets(
    'character references become continuous prose without a visual signal',
    (tester) async {
      await makeComposer(tester);
      final paragraph =
          const MarkdownDocumentParser()
                  .parse('&quot;quoted&quot; and an ellipsis&#46;&#46;&#46;')
                  .blocks
                  .single
              as ParagraphBlock;

      expect(paragraph.content, everyElement(isA<TextRun>()));
      expect(rendered(paragraph.content), '“quoted” and an ellipsis…');
    },
  );

  testWidgets('plain Unicode is composed one grapheme at a time', (
    tester,
  ) async {
    await makeComposer(tester);
    const source = 'nai\u0308ve 👩🏽‍💻 beside العربية and 中文。';
    final combining = source.indexOf('\u0308');
    final modifier = source.indexOf('🏽');
    final spans = InlineComposer(
      theme: theme,
      matches: [
        TextMatch(start: combining, end: combining + 1, excerpt: 'ï'),
        TextMatch(start: modifier, end: modifier + 2, excerpt: '👩🏽‍💻'),
      ],
    ).compose(const [TextRun(source)]);

    final highlighted = <String>[];
    void collect(InlineSpan span) {
      if (span is! TextSpan) return;
      if (span.text != null && span.style?.backgroundColor != null) {
        highlighted.add(span.text!);
      }
      span.children?.forEach(collect);
    }

    spans.forEach(collect);
    expect(TextSpan(children: spans).toPlainText(), source);
    expect(highlighted, ['i\u0308', '👩🏽‍💻']);
  });

  testWidgets('verbatim highlighting never bisects an emoji sequence', (
    tester,
  ) async {
    await makeComposer(tester);
    const source = 'print("👩🏽‍💻")';
    final joiner = source.indexOf('\u200d');
    final spans =
        InlineComposer(
          theme: theme,
          matches: [TextMatch(start: joiner, end: joiner + 1, excerpt: source)],
        ).highlightedVerbatim(
          source,
          style: theme.code,
          highlighting: null,
          styleFor: (_) => theme.code,
        );

    final highlighted = spans
        .whereType<TextSpan>()
        .where((span) => span.style?.backgroundColor != null)
        .map((span) => span.text)
        .toList();
    expect(TextSpan(children: spans).toPlainText(), source);
    expect(highlighted, ['👩🏽‍💻']);
  });

  testWidgets('a match crosses marked runs without changing punctuation', (
    tester,
  ) async {
    await makeComposer(tester);
    final highlighted =
        InlineComposer(
          theme: theme,
          matches: const [TextMatch(start: 5, end: 11, excerpt: 'needle')],
          activeMatch: 0,
        ).compose(const [
          TextRun('Find nee'),
          MarkedRun(InlineMark.strong, [TextRun('dle')]),
          TextRun(' now...'),
        ]);

    final marked = StringBuffer();
    void walk(InlineSpan span) {
      if (span is! TextSpan) return;
      if (span.text != null && span.style?.backgroundColor != null) {
        marked.write(span.text);
      }
      span.children?.forEach(walk);
    }

    highlighted.forEach(walk);
    expect(TextSpan(children: highlighted).toPlainText(), 'Find needle now…');
    expect(marked.toString(), 'needle');
  });

  testWidgets('emphasis adds only italic and keeps search paint independent', (
    tester,
  ) async {
    await makeComposer(tester);
    final paragraph =
        const MarkdownDocumentParser()
                .parse('*asterisk* and _underscore_')
                .blocks
                .single
            as ParagraphBlock;
    final matchStart = paragraph.text.indexOf('underscore');
    const base = TextStyle(
      color: Color(0xFF123456),
      fontSize: 19,
      height: 1.6,
      fontWeight: FontWeight.w400,
    );
    final spans = InlineComposer(
      theme: theme,
      matches: [
        TextMatch(
          start: matchStart,
          end: matchStart + 'underscore'.length,
          excerpt: paragraph.text,
        ),
      ],
    ).compose(paragraph.content, style: base);

    final emphasizedLeaves = <TextSpan>[];
    void collect(InlineSpan span, {bool insideEmphasis = false}) {
      if (span is! TextSpan) return;
      final emphasized =
          insideEmphasis || span.style?.fontStyle == FontStyle.italic;
      if (emphasized && span.text != null) emphasizedLeaves.add(span);
      for (final child in span.children ?? const <InlineSpan>[]) {
        collect(child, insideEmphasis: emphasized);
      }
    }

    spans.forEach(collect);
    expect(TextSpan(children: spans).toPlainText(), 'asterisk and underscore');
    expect(emphasizedLeaves.map((span) => span.text), [
      'asterisk',
      'underscore',
    ]);
    for (final leaf in emphasizedLeaves) {
      expect(leaf.style!.fontStyle, FontStyle.italic);
      expect(leaf.style!.fontWeight, base.fontWeight);
      expect(leaf.style!.color, base.color);
      expect(leaf.style!.fontSize, base.fontSize);
      expect(leaf.style!.height, base.height);
      expect(leaf.style!.decoration, base.decoration);
      expect(leaf.semanticsLabel, isNull);
    }
    expect(emphasizedLeaves.first.style!.backgroundColor, isNull);
    expect(
      emphasizedLeaves.last.style!.backgroundColor,
      theme.palette.selection,
    );
  });

  testWidgets('strength adds only weight and keeps search paint independent', (
    tester,
  ) async {
    await makeComposer(tester);
    final paragraph =
        const MarkdownDocumentParser()
                .parse('**asterisk** and __underscore__')
                .blocks
                .single
            as ParagraphBlock;
    final matchStart = paragraph.text.indexOf('underscore');
    const base = TextStyle(
      color: Color(0xFF123456),
      fontSize: 19,
      height: 1.6,
      fontWeight: FontWeight.w400,
    );
    final spans = InlineComposer(
      theme: theme,
      matches: [
        TextMatch(
          start: matchStart,
          end: matchStart + 'underscore'.length,
          excerpt: paragraph.text,
        ),
      ],
    ).compose(paragraph.content, style: base);

    final strongLeaves = <TextSpan>[];
    void collect(InlineSpan span, {bool insideStrength = false}) {
      if (span is! TextSpan) return;
      final strong =
          insideStrength || span.style?.fontWeight == FontWeight.w700;
      if (strong && span.text != null) strongLeaves.add(span);
      for (final child in span.children ?? const <InlineSpan>[]) {
        collect(child, insideStrength: strong);
      }
    }

    spans.forEach(collect);
    expect(TextSpan(children: spans).toPlainText(), 'asterisk and underscore');
    expect(strongLeaves.map((span) => span.text), ['asterisk', 'underscore']);
    for (final leaf in strongLeaves) {
      expect(leaf.style!.fontWeight, FontWeight.w700);
      expect(leaf.style!.fontStyle, base.fontStyle);
      expect(leaf.style!.color, base.color);
      expect(leaf.style!.fontSize, base.fontSize);
      expect(leaf.style!.height, base.height);
      expect(leaf.style!.decoration, base.decoration);
      expect(leaf.semanticsLabel, isNull);
    }
    expect(strongLeaves.first.style!.backgroundColor, isNull);
    expect(strongLeaves.last.style!.backgroundColor, theme.palette.selection);
  });

  testWidgets('nested marks accumulate their two independent signals', (
    tester,
  ) async {
    await makeComposer(tester);
    final paragraph =
        const MarkdownDocumentParser()
                .parse('***combined*** beside **outer *inner* tail**')
                .blocks
                .single
            as ParagraphBlock;
    const base = TextStyle(
      color: Color(0xFF123456),
      fontSize: 19,
      height: 1.6,
      fontWeight: FontWeight.w400,
      fontStyle: FontStyle.normal,
    );
    final spans = InlineComposer(
      theme: theme,
      matches: const [TextMatch(start: 0, end: 8, excerpt: 'combined')],
    ).compose(paragraph.content, style: base);

    final leaves = <TextSpan>[];
    void collect(InlineSpan span) {
      if (span is! TextSpan) return;
      if (span.text != null) leaves.add(span);
      span.children?.forEach(collect);
    }

    spans.forEach(collect);
    TextStyle styleContaining(String text) =>
        leaves.singleWhere((span) => span.text!.contains(text)).style!;

    final combined = styleContaining('combined');
    final outer = styleContaining('outer');
    final inner = styleContaining('inner');
    expect(
      TextSpan(children: spans).toPlainText(),
      'combined beside outer inner tail',
    );
    expect(combined.fontStyle, FontStyle.italic);
    expect(combined.fontWeight, FontWeight.w700);
    expect(combined.backgroundColor, theme.palette.selection);
    expect(outer.fontStyle, FontStyle.normal);
    expect(outer.fontWeight, FontWeight.w700);
    expect(inner.fontStyle, FontStyle.italic);
    expect(inner.fontWeight, FontWeight.w700);
    for (final style in [combined, outer, inner]) {
      expect(style.color, base.color);
      expect(style.fontSize, base.fontSize);
      expect(style.height, base.height);
      expect(style.decoration, base.decoration);
    }
    expect(leaves.every((span) => span.semanticsLabel == null), isTrue);
  });

  testWidgets(
    'strikethrough adds only a line and keeps search paint independent',
    (tester) async {
      await makeComposer(tester);
      final paragraph =
          const MarkdownDocumentParser()
                  .parse('~single~ and ~~double~~')
                  .blocks
                  .single
              as ParagraphBlock;
      final matchStart = paragraph.text.indexOf('double');
      const base = TextStyle(
        color: Color(0xFF123456),
        fontSize: 19,
        height: 1.6,
        fontWeight: FontWeight.w400,
        fontStyle: FontStyle.normal,
      );
      final spans = InlineComposer(
        theme: theme,
        matches: [
          TextMatch(
            start: matchStart,
            end: matchStart + 'double'.length,
            excerpt: paragraph.text,
          ),
        ],
      ).compose(paragraph.content, style: base);

      final deletedLeaves = <TextSpan>[];
      void collect(InlineSpan span, {bool insideDeletion = false}) {
        if (span is! TextSpan) return;
        final deleted =
            insideDeletion ||
            span.style?.decoration == TextDecoration.lineThrough;
        if (deleted && span.text != null) deletedLeaves.add(span);
        for (final child in span.children ?? const <InlineSpan>[]) {
          collect(child, insideDeletion: deleted);
        }
      }

      spans.forEach(collect);
      expect(TextSpan(children: spans).toPlainText(), 'single and double');
      expect(deletedLeaves.map((span) => span.text), ['single', 'double']);
      for (final leaf in deletedLeaves) {
        expect(leaf.style!.decoration, TextDecoration.lineThrough);
        expect(leaf.style!.color, base.color);
        expect(leaf.style!.fontSize, base.fontSize);
        expect(leaf.style!.height, base.height);
        expect(leaf.style!.fontWeight, base.fontWeight);
        expect(leaf.style!.fontStyle, base.fontStyle);
        expect(leaf.semanticsLabel, isNull);
      }
      expect(deletedLeaves.first.style!.backgroundColor, isNull);
      expect(
        deletedLeaves.last.style!.backgroundColor,
        theme.palette.selection,
      );
    },
  );

  testWidgets(
    'scientific and inserted text use designed glyphs without changing rhythm',
    (tester) async {
      await makeComposer(tester);
      const base = TextStyle(
        color: Color(0xFF123456),
        fontFamily: 'Literata',
        fontSize: 20,
        height: 1.6,
        fontFeatures: [FontFeature.oldstyleFigures()],
      );
      final spans = InlineComposer(theme: theme).compose(const [
        MarkedRun(InlineMark.subscript, [TextRun('H2O')]),
        MarkedRun(InlineMark.superscript, [TextRun('x2')]),
        MarkedRun(InlineMark.subscript, [
          MarkedRun(InlineMark.superscript, [TextRun('nested')]),
        ]),
        MarkedRun(InlineMark.insertion, [
          MarkedRun(InlineMark.strikethrough, [TextRun('revision')]),
        ]),
      ], style: base);

      final leaves = <TextSpan>[];
      void collect(InlineSpan span) {
        if (span is! TextSpan) return;
        if (span.text != null) leaves.add(span);
        span.children?.forEach(collect);
      }

      spans.forEach(collect);
      expect(TextSpan(children: spans).toPlainText(), 'H2Ox2nestedrevision');
      for (final leaf in leaves) {
        expect(leaf.style!.fontSize, base.fontSize);
        expect(leaf.style!.height, base.height);
        expect(leaf.style!.color, base.color);
      }
      expect(leaves[0].style!.fontFeatures, const [
        FontFeature.oldstyleFigures(),
        FontFeature.subscripts(),
      ]);
      expect(leaves[1].style!.fontFeatures, const [
        FontFeature.oldstyleFigures(),
        FontFeature.superscripts(),
      ]);
      expect(leaves[2].style!.fontFeatures, const [
        FontFeature.oldstyleFigures(),
        FontFeature.superscripts(),
      ]);
      expect(
        leaves[3].style!.decoration!.contains(TextDecoration.underline),
        isTrue,
      );
      expect(
        leaves[3].style!.decoration!.contains(TextDecoration.lineThrough),
        isTrue,
      );
      expect(leaves.every((leaf) => leaf.semanticsLabel == null), isTrue);
    },
  );

  testWidgets(
    'scientific and insertion marks survive inline code without styling links',
    (tester) async {
      await makeComposer(tester);
      final spans = composer.compose(const [
        MarkedRun(InlineMark.subscript, [CodeRun('2')]),
        MarkedRun(InlineMark.superscript, [CodeRun('n')]),
        MarkedRun(InlineMark.insertion, [CodeRun('new')]),
        LinkRun(href: '/plain-code', children: [CodeRun('link')]),
      ]);

      final leaves = <TextSpan>[];
      void collect(InlineSpan span) {
        if (span is! TextSpan) return;
        if (span.text != null) leaves.add(span);
        span.children?.forEach(collect);
      }

      spans.forEach(collect);
      expect(
        leaves[0].style!.fontFeatures,
        contains(const FontFeature.subscripts()),
      );
      expect(
        leaves[1].style!.fontFeatures,
        contains(const FontFeature.superscripts()),
      );
      expect(
        leaves[2].style!.decoration!.contains(TextDecoration.underline),
        isTrue,
      );
      expect(leaves[3].style!.decoration, TextDecoration.none);
    },
  );

  testWidgets(
    'an authored line remains one selectable newline in the text flow',
    (tester) async {
      await makeComposer(tester);
      final composed =
          InlineComposer(
            theme: theme,
            matches: const [TextMatch(start: 6, end: 12, excerpt: 'second')],
            activeMatch: 0,
          ).compose(const [
            TextRun('first'),
            LineBreakRun(),
            MarkedRun(InlineMark.strong, [TextRun('second')]),
            LineBreakRun(),
            LinkRun(href: '#third', children: [TextRun('third')]),
          ]);

      final highlighted = StringBuffer();
      void collect(InlineSpan span) {
        if (span is! TextSpan) return;
        if (span.text != null && span.style?.backgroundColor != null) {
          highlighted.write(span.text);
        }
        span.children?.forEach(collect);
      }

      composed.forEach(collect);
      expect(
        TextSpan(children: composed).toPlainText(),
        'first\nsecond\nthird',
      );
      expect(highlighted.toString(), 'second');
    },
  );

  testWidgets('code is composed exactly as written', (tester) async {
    await makeComposer(tester);
    expect(
      rendered([const CodeRun('git log --oneline "HEAD"...')]),
      'git log --oneline "HEAD"...',
    );
  });

  testWidgets(
    'inline code remains selectable text and never borrows the link underline',
    (tester) async {
      await makeComposer(tester);
      final span =
          composer.compose([const CodeRun('DocumentOutline.parse')]).single
              as TextSpan;

      expect(span.text, 'DocumentOutline.parse');
      expect(span.toPlainText(), 'DocumentOutline.parse');
      expect(span.style!.fontFamily, theme.code.fontFamily);
      expect(span.style!.backgroundColor, isNull);
      expect(span.style!.decoration, TextDecoration.none);
      expect(
        ThemePalette.contrastRatio(span.style!.color!, theme.palette.paper),
        greaterThanOrEqualTo(ThemePalette.minimumTextContrast),
      );
      expect(span.style!.decorationColor, isNull);
      expect(span.style!.decorationThickness, isNull);
      final features = {
        for (final feature in span.style!.fontFeatures!)
          feature.feature: feature.value,
      };
      expect(features['zero'], 1);
      expect(features['liga'], 0);
      expect(features['calt'], 0);
      expect(features['dlig'], 0);
    },
  );

  testWidgets('every theme gives inline code text strong contrast', (
    tester,
  ) async {
    for (final candidate in BuiltInThemes.all) {
      late ReadingTheme reading;
      await tester.pumpWidget(
        MaterialApp(
          theme: libraryTheme(candidate),
          home: Builder(
            builder: (context) {
              reading = ReadingTheme.of(context, ReadingScale.comfortable);
              return const SizedBox();
            },
          ),
        ),
      );
      final codeText = reading.inlineCodeFor(reading.body).color!;
      expect(
        ThemePalette.contrastRatio(codeText, reading.palette.paper),
        greaterThanOrEqualTo(ThemePalette.minimumTextContrast),
        reason: candidate.name,
      );
    }
  });

  testWidgets('short symbols and long commands share the selectable flow', (
    tester,
  ) async {
    await makeComposer(tester);
    const path = 'lib/domain/reading/document_outline.dart:7-42';
    final longPath = composer.compose([const CodeRun(path)]).single;
    final command = composer.compose([
      const CodeRun('git log --oneline'),
    ]).single;

    expect(longPath, isA<TextSpan>());
    expect((longPath as TextSpan).text, path);
    expect(command, isA<TextSpan>());
    expect((command as TextSpan).toPlainText(), 'git log --oneline');
  });

  testWidgets('an unbroken inline reference wraps inside the reading column', (
    tester,
  ) async {
    const source =
        'VisualMdWorkspaceDocumentRootAbsolutePathWithoutAnyBreakOpportunity'
        'AndWithEnoughCharactersToCrossSeveralNarrowLines';
    await tester.pumpWidget(
      MaterialApp(
        theme: libraryTheme(BuiltInThemes.paper),
        home: Center(
          child: SizedBox(
            width: 180,
            child: Builder(
              builder: (context) {
                final reading = ReadingTheme.of(
                  context,
                  ReadingScale.comfortable,
                );
                final inline = InlineComposer(theme: reading);
                return Paragraph(
                  spans: inline.compose(const [CodeRun(source)]),
                  style: reading.body,
                  textScaler: reading.textScaler,
                  strut: reading.strutFor(reading.body),
                );
              },
            ),
          ),
        ),
      ),
    );

    final render = tester.renderObject<RenderParagraph>(
      find.descendant(
        of: find.byType(Paragraph),
        matching: find.byType(RichText),
      ),
    );
    final boxes = render.getBoxesForSelection(
      const TextSelection(baseOffset: 0, extentOffset: source.length),
    );
    expect(boxes.length, greaterThan(2));
    expect(
      boxes.every((box) => box.toRect().right <= render.size.width + 0.01),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a reader can select and copy only the backticked reference', (
    tester,
  ) async {
    await makeComposer(tester);
    const code = 'DocumentOutline.parse';
    final paragraph = GlobalKey();
    Map<Object?, Object?>? clipboard;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map<Object?, Object?>);
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: libraryTheme(BuiltInThemes.paper),
        home: SelectionArea(
          child: Text.rich(
            key: paragraph,
            TextSpan(
              children: composer.compose(const [
                TextRun('before '),
                CodeRun(code),
                TextRun(' after'),
              ]),
            ),
          ),
        ),
      ),
    );

    final render = tester.renderObject<RenderParagraph>(
      find.descendant(
        of: find.byKey(paragraph),
        matching: find.byType(RichText),
      ),
    );
    final start = 'before '.length;
    final first = render
        .getBoxesForSelection(
          TextSelection(baseOffset: start, extentOffset: start + 1),
        )
        .single
        .toRect();
    final last = render
        .getBoxesForSelection(
          TextSelection(
            baseOffset: start + code.length - 1,
            extentOffset: start + code.length,
          ),
        )
        .single
        .toRect();
    final gesture = await tester.startGesture(
      render.localToGlobal(first.centerLeft),
      kind: PointerDeviceKind.mouse,
    );
    addTearDown(gesture.removePointer);
    await tester.pump();
    await gesture.moveTo(render.localToGlobal(last.centerRight));
    await tester.pump();
    await gesture.up();
    Actions.invoke(paragraph.currentContext!, CopySelectionTextIntent.copy);
    await tester.pump();

    expect(clipboard?['text'], code);
  });

  testWidgets('a quote after a marked run closes rather than opens', (
    tester,
  ) async {
    await makeComposer(tester);
    // …strong text followed by a closing quote: the mark ends a word.
    final runs = [
      const MarkedRun(InlineMark.strong, [TextRun('bold')]),
      const TextRun('" said she'),
    ];
    expect(rendered(runs), 'bold” said she');
  });

  testWidgets('whitespace inside a marked run still opens the next quote', (
    tester,
  ) async {
    await makeComposer(tester);
    expect(
      rendered([
        const MarkedRun(InlineMark.strong, [TextRun('A pause ')]),
        const TextRun('"then this"'),
      ]),
      'A pause “then this”',
    );
  });

  testWidgets('marks nest, and a link keeps the weight it is wrapped in', (
    tester,
  ) async {
    await makeComposer(tester);
    final spans = composer.compose([
      const MarkedRun(InlineMark.strong, [
        TextRun('very '),
        MarkedRun(InlineMark.emphasis, [TextRun('very')]),
      ]),
    ]);
    final strong = spans.single as TextSpan;
    final nested =
        (strong.children!.last as TextSpan).children!.single as TextSpan;
    expect(nested.style!.fontWeight, FontWeight.w700);
    expect(nested.style!.fontStyle, FontStyle.italic);
  });

  testWidgets('a link reports where it points when tapped', (tester) async {
    await makeComposer(tester);
    final spans = composer.compose([
      const LinkRun(href: 'guide/intro.md', children: [TextRun('the guide')]),
    ]);
    await tester.pumpWidget(
      MaterialApp(home: Text.rich(TextSpan(children: spans))),
    );

    final text = find.byType(RichText);
    await tester.tapAt(tester.getTopLeft(text) + const Offset(4, 10));
    await tester.pump();
    expect(tapped, ['guide/intro.md']);
  });

  testWidgets('a link adds only its two interaction signals', (tester) async {
    await makeComposer(tester);
    const base = TextStyle(
      color: Color(0xFF123456),
      fontSize: 19,
      height: 1.6,
      fontWeight: FontWeight.w700,
      fontStyle: FontStyle.italic,
    );
    final span =
        composer.compose([
              const LinkRun(href: '/guide', children: [TextRun('the guide')]),
            ], style: base).single
            as TextSpan;
    final leaf = span.children!.single as TextSpan;

    expect(leaf.style!.color, theme.palette.accent);
    expect(leaf.style!.decoration, TextDecoration.underline);
    expect(
      leaf.style!.decorationColor,
      theme.palette.accent.withValues(alpha: 0.4),
    );
    expect(leaf.style!.fontSize, base.fontSize);
    expect(leaf.style!.height, base.height);
    expect(leaf.style!.fontWeight, base.fontWeight);
    expect(leaf.style!.fontStyle, base.fontStyle);
  });

  testWidgets('a link retains the editorial marks wrapped around it', (
    tester,
  ) async {
    await makeComposer(tester);
    final span =
        composer.compose(const [
              MarkedRun(InlineMark.strikethrough, [
                MarkedRun(InlineMark.insertion, [
                  LinkRun(href: '/revision', children: [TextRun('revision')]),
                ]),
              ]),
            ]).single
            as TextSpan;
    final insertion = span.children!.single as TextSpan;
    final link = insertion.children!.single as TextSpan;
    final leaf = link.children!.single as TextSpan;

    expect(leaf.style!.decoration!.contains(TextDecoration.underline), isTrue);
    expect(
      leaf.style!.decoration!.contains(TextDecoration.lineThrough),
      isTrue,
    );
    expect(leaf.style!.color, theme.palette.accent);
  });

  testWidgets('the visible words are an actionable link for accessibility', (
    tester,
  ) async {
    await makeComposer(tester);
    final semantics = tester.ensureSemantics();
    final spans = composer.compose([
      const LinkRun(
        href: '/guide',
        title: 'Advisory title',
        children: [
          TextRun('the '),
          MarkedRun(InlineMark.strong, [TextRun('visible')]),
          TextRun(' guide'),
        ],
      ),
    ]);
    await tester.pumpWidget(
      MaterialApp(home: Text.rich(TextSpan(children: spans))),
    );

    final paragraph = tester.getSemantics(find.byType(RichText));
    final link = paragraph
        .debugListChildrenInOrder(DebugSemanticsDumpOrder.traversalOrder)
        .single;
    expect(
      link,
      matchesSemantics(
        label: 'the visible guide',
        textDirection: TextDirection.ltr,
        isLink: true,
        hasTapAction: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets('a link title never replaces or invalidates its visible label', (
    tester,
  ) async {
    await makeComposer(tester);
    final span =
        composer.compose([
              const LinkRun(
                href: 'https://example.com',
                title: 'Example title',
                children: [TextRun('titled link')],
              ),
            ]).single
            as TextSpan;

    expect(span.toPlainText(), 'titled link');
    expect(span.semanticsLabel, isNull);
  });

  testWidgets('a link owns the typographic glyphs the reader can see', (
    tester,
  ) async {
    await makeComposer(tester);
    final span =
        composer.compose([
              const LinkRun(
                href: '/guide',
                children: [TextRun('"guide"---now')],
              ),
            ]).single
            as TextSpan;

    expect(span.toPlainText(), '“guide”—now');
    expect(span.getSemanticsInformation().single.text, '“guide”—now');
  });

  testWidgets(
    'one long link reflows without losing any line of its hit target',
    (tester) async {
      const label =
          'A linked explanation with nested language and the unbroken token '
          'VisualMdWorkspaceDocumentRootAbsolutePathWithoutAnyBreakOpportunity'
          'AndWithEnoughCharactersToCrossSeveralNarrowLines still belongs to '
          'one destination.';
      const href = 'https://example.com/one/very/long/destination';
      final activations = <String>[];
      late ReadingTheme reading;
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(
        MaterialApp(
          theme: libraryTheme(BuiltInThemes.paper),
          home: Center(
            child: SizedBox(
              width: 220,
              child: Builder(
                builder: (context) {
                  reading = ReadingTheme.of(context, ReadingScale.comfortable);
                  final inline = InlineComposer(
                    theme: reading,
                    onTapLink: activations.add,
                  );
                  return Paragraph(
                    spans: inline.compose(const [
                      LinkRun(href: href, children: [TextRun(label)]),
                    ]),
                    style: reading.body,
                    textScaler: reading.textScaler,
                    strut: reading.strutFor(reading.body),
                  );
                },
              ),
            ),
          ),
        ),
      );

      final render = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: find.byType(Paragraph),
          matching: find.byType(RichText),
        ),
      );
      final boxes = render.getBoxesForSelection(
        const TextSelection(baseOffset: 0, extentOffset: label.length),
      );
      final lines = <double, Rect>{};
      for (final box in boxes) {
        lines.putIfAbsent(box.top, box.toRect);
      }

      expect(lines.length, greaterThan(4));
      expect(
        boxes.every((box) => box.toRect().right <= render.size.width + 0.01),
        isTrue,
      );
      for (final line in lines.values) {
        await tester.tapAt(render.localToGlobal(line.center));
        await tester.pump();
      }
      expect(activations, everyElement(href));
      expect(activations, hasLength(lines.length));
      final paragraph = tester.getSemantics(
        find.descendant(
          of: find.byType(Paragraph),
          matching: find.byType(RichText),
        ),
      );
      final link = paragraph
          .debugListChildrenInOrder(DebugSemanticsDumpOrder.traversalOrder)
          .single;
      expect(
        link,
        matchesSemantics(
          label: label,
          textDirection: TextDirection.ltr,
          isLink: true,
          hasTapAction: true,
        ),
      );
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets('an empty link creates no invisible interaction target', (
    tester,
  ) async {
    await makeComposer(tester);
    final semantics = tester.ensureSemantics();
    final spans = composer.compose(const [
      TextRun('before '),
      LinkRun(href: '/invisible', children: []),
      TextRun('after'),
    ]);
    await tester.pumpWidget(
      MaterialApp(home: Text.rich(TextSpan(children: spans))),
    );

    expect(TextSpan(children: spans).toPlainText(), 'before after');
    final paragraph = tester.getSemantics(find.byType(RichText));
    final children = paragraph.debugListChildrenInOrder(
      DebugSemanticsDumpOrder.traversalOrder,
    );
    expect(
      children.where((node) {
        final data = node.getSemanticsData();
        return data.flagsCollection.isLink ||
            data.hasAction(SemanticsAction.tap);
      }),
      isEmpty,
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('inline custom anchor syntax inserts no selectable placeholder', (
    tester,
  ) async {
    await makeComposer(tester);
    const parser = MarkdownDocumentParser();
    final block =
        parser.parse('before <a name="middle"></a>"after"').blocks.single
            as ParagraphBlock;
    final spans = InlineComposer(theme: theme).compose(block.content);
    final paragraph = TextSpan(children: spans);
    await tester.pumpWidget(MaterialApp(home: Text.rich(paragraph)));

    expect(paragraph.toPlainText(), 'before “after”');
    expect(
      paragraph.getSemanticsInformation().map((entry) => entry.text).join(),
      'before “after”',
    );
    expect(spans.whereType<WidgetSpan>(), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('links keep the typographic role around them', (tester) async {
    await makeComposer(tester);
    final heading = theme.heading(2);
    final linkedHeading =
        composer.compose([
              const LinkRun(href: 'part.md', children: [TextRun('the part')]),
            ], style: heading).single
            as TextSpan;
    final headingText = linkedHeading.children!.single as TextSpan;
    expect(headingText.style!.fontSize, heading.fontSize);
    expect(headingText.style!.height, heading.height);
    expect(headingText.style!.fontWeight, heading.fontWeight);

    final linkedTable =
        composer.compose([
              const LinkRun(href: 'cell.md', children: [TextRun('12')]),
            ], style: theme.tableBody).single
            as TextSpan;
    final tableText = linkedTable.children!.single as TextSpan;
    expect(tableText.style!.fontSize, theme.tableBody.fontSize);
    expect(tableText.style!.fontFeatures, theme.tableBody.fontFeatures);
  });

  testWidgets('inline code scales with the role it appears in', (tester) async {
    await makeComposer(tester);
    TextStyle styleOf(InlineSpan span) => (span as TextSpan).style!;

    final bodyCode = styleOf(composer.compose([const CodeRun('x')]).single);
    final headingCode = styleOf(
      composer.compose([const CodeRun('x')], style: theme.heading(1)).single,
    );

    expect(headingCode.fontSize, greaterThan(bodyCode.fontSize!));
    expect(headingCode.fontFamily, theme.code.fontFamily);
    expect(
      FontMetrics.letterSizeFor(bodyCode.fontFamily!, bodyCode.fontSize!),
      closeTo(17, 0.001),
    );
    expect(
      FontMetrics.letterSizeFor(headingCode.fontFamily!, headingCode.fontSize!),
      closeTo(ReadingScale.comfortable.heading(1) - 1, 0.001),
    );
  });

  testWidgets('an unresolved image still says what it was meant to say', (
    tester,
  ) async {
    await makeComposer(tester);
    expect(
      rendered([const ImageRun(source: 'a.png', alt: 'A diagram')]),
      'A diagram',
    );
  });

  testWidgets('a resolvable image becomes an inline widget', (tester) async {
    await makeComposer(tester);
    final spans = InlineComposer(
      theme: theme,
      document: DocumentId(const LibraryRootId('notes'), 'guide/page.md'),
      imageLoader: const _MissingImageLoader(),
    ).compose(const [ImageRun(source: 'a.png', alt: 'A diagram')]);

    expect(spans.single, isA<WidgetSpan>());
    expect((spans.single as WidgetSpan).child, isA<DocumentImage>());
  });
}
