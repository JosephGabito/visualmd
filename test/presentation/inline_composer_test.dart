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
import 'package:visualmd/domain/reading/content/inline.dart';
import 'package:visualmd/domain/search/search_result.dart';
import 'package:visualmd/presentation/theme/built_in_themes.dart';
import 'package:visualmd/presentation/theme/reading_scale.dart';
import 'package:visualmd/presentation/theme/theme_palette.dart';

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

  testWidgets('code is composed exactly as written', (tester) async {
    await makeComposer(tester);
    expect(
      rendered([const CodeRun('git log --oneline "HEAD"...')]),
      'git log --oneline "HEAD"...',
    );
  });

  testWidgets(
    'inline code remains selectable text with strong colour and a quiet underline',
    (tester) async {
      await makeComposer(tester);
      final span =
          composer.compose([const CodeRun('DocumentOutline.parse')]).single
              as TextSpan;

      expect(span.text, 'DocumentOutline.parse');
      expect(span.toPlainText(), 'DocumentOutline.parse');
      expect(span.style!.fontFamily, theme.code.fontFamily);
      expect(span.style!.backgroundColor, isNull);
      expect(span.style!.decoration, TextDecoration.underline);
      expect(
        ThemePalette.contrastRatio(span.style!.color!, theme.palette.paper),
        greaterThanOrEqualTo(ThemePalette.minimumTextContrast),
      );
      expect(
        span.style!.decorationColor,
        theme.palette.muted.withValues(alpha: 0.4),
      );
      expect(span.style!.decorationThickness, 1.25);
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
    final span =
        composer.compose([
              const LinkRun(
                href: 'guide/intro.md',
                children: [TextRun('the guide')],
              ),
            ]).single
            as TextSpan;

    expect(span.style ?? (span.children!.single as TextSpan).style, isNotNull);
    (span.recognizer! as TapGestureRecognizer).onTap!();
    expect(tapped, ['guide/intro.md']);
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
}
