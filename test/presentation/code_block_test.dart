import 'dart:ui' show Tristate;
import 'dart:math' as math;

import 'package:flutter/material.dart' hide TableCell;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/api/render/document_view.dart';
import 'package:visualmd/api/render/reading_theme.dart';
import 'package:visualmd/api/theme/library_theme.dart';
import 'package:visualmd/api/widgets/code_block.dart';
import 'package:visualmd/domain/reading/content/block.dart';
import 'package:visualmd/domain/reading/content/document_content.dart';
import 'package:visualmd/domain/search/search_result.dart';
import 'package:visualmd/presentation/code/code_highlighter.dart';
import 'package:visualmd/presentation/theme/built_in_themes.dart';
import 'package:visualmd/presentation/theme/reading_scale.dart';
import 'package:visualmd/presentation/theme/reader_theme.dart';
import 'package:visualmd/presentation/theme/theme_palette.dart';

const _longLine =
    'final library = LibraryBuilder.build(name: "notes", files: files, extra: 1);';

final class _FakeHighlighter implements CodeHighlighter {
  final CodeHighlighting? result;
  final bool throws;
  int calls = 0;

  _FakeHighlighter({this.result, this.throws = false});

  @override
  String labelFor(String? language) => switch (language) {
    'py' => 'Python',
    null || '' => 'Text',
    final name => name,
  };

  @override
  Future<CodeHighlighting?> highlight({
    required String source,
    required String? language,
    required CodeHighlightScheme scheme,
  }) async {
    calls++;
    if (throws) throw StateError('grammar failed');
    return result;
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

  Future<void> pumpCode(
    WidgetTester tester,
    String code, {
    double width = 520,
    String? language,
    CodeHighlighter highlighter = const PlainCodeHighlighter(),
    List<TextMatch> matches = const [],
    int activeMatch = -1,
    DocumentContent? content,
    ReaderTheme readerTheme = BuiltInThemes.paper,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: libraryTheme(readerTheme),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: Builder(
                builder: (context) {
                  return DocumentView(
                    content:
                        content ??
                        DocumentContent([
                          CodeBlock(code: code, language: language),
                        ]),
                    theme: ReadingTheme.of(context, ReadingScale.comfortable),
                    codeHighlighter: highlighter,
                    anchorKeys: {},
                    matches: matches,
                    activeMatch: activeMatch,
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

  Finder horizontalScroller() => find.byWidgetPredicate(
    (widget) =>
        widget is SingleChildScrollView &&
        widget.scrollDirection == Axis.horizontal,
  );

  ScrollPosition horizontalPosition(WidgetTester tester) => tester
      .widget<SingleChildScrollView>(horizontalScroller())
      .controller!
      .position;

  Text sourceText(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const ValueKey('code-source')));

  testWidgets('a long line scrolls sideways instead of being cut off', (
    tester,
  ) async {
    await pumpCode(tester, _longLine);

    final position = horizontalPosition(tester);
    expect(position.maxScrollExtent, greaterThan(0));
    position.jumpTo(position.maxScrollExtent);
    await tester.pump();
    expect(sourceText(tester).textSpan!.toPlainText(), _longLine);

    final scrollbar = tester.widget<Scrollbar>(find.byType(Scrollbar));
    expect(scrollbar.thumbVisibility, isTrue);
    expect(
      tester
          .widget<ScrollbarTheme>(find.byType(ScrollbarTheme))
          .data
          .thickness!
          .resolve({}),
      4,
    );
  });

  testWidgets('wrapping is local, reversible, and removes horizontal scroll', (
    tester,
  ) async {
    await pumpCode(tester, _longLine, width: 360);

    expect(sourceText(tester).softWrap, isFalse);
    expect(horizontalScroller(), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('code-wrap')));
    await tester.pump();
    expect(sourceText(tester).softWrap, isTrue);
    expect(horizontalScroller(), findsNothing);

    await tester.tap(find.byKey(const ValueKey('code-wrap')));
    await tester.pump();
    expect(sourceText(tester).softWrap, isFalse);
    expect(horizontalScroller(), findsOneWidget);
  });

  testWidgets('the wrap action is keyboard reachable', (tester) async {
    await pumpCode(tester, _longLine, width: 360);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(sourceText(tester).softWrap, isTrue);
  });

  testWidgets('copy sends the exact source and confirms completion', (
    tester,
  ) async {
    const source = 'first\tline\n\nlast  ';
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map<Object?, Object?>)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await pumpCode(tester, source);

    await tester.tap(find.byKey(const ValueKey('code-copy')));
    await tester.pump();

    expect(copied, source);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });

  testWidgets(
    'a huge fence keeps exact copy while its mounted lines follow the page',
    (tester) async {
      final source = List.generate(
        2000,
        (index) =>
            'final value_$index = compute(input_$index); // bounded source row',
      ).join('\n');
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied =
                (call.arguments as Map<Object?, Object?>)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: libraryTheme(BuiltInThemes.paper),
          home: Scaffold(
            body: SelectionArea(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Builder(
                      builder: (context) => DocumentView(
                        content: DocumentContent([
                          CodeBlock(code: source, language: 'dart'),
                        ]),
                        theme: ReadingTheme.of(
                          context,
                          ReadingScale.comfortable,
                        ),
                        anchorKeys: {},
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      int lineIndex(Element element) => int.parse(
        (element.widget.key! as ValueKey<String>).value.substring(10),
      );
      Iterable<Element> mountedLines() => find.byWidgetPredicate((widget) {
        final key = widget.key;
        return key is ValueKey<String> && key.value.startsWith('code-line-');
      }).evaluate();

      expect(mountedLines().length, lessThan(100));
      await tester.tap(find.byKey(const ValueKey('code-copy')));
      await tester.pump();
      expect(copied, source);

      final vertical = find.descendant(
        of: find.byType(CustomScrollView),
        matching: find.byType(Scrollable),
      );
      final position = tester.state<ScrollableState>(vertical.first).position;
      position.jumpTo(position.maxScrollExtent * 0.5);
      await tester.pump();
      await tester.pump();

      final middle = mountedLines().toList(growable: false);
      expect(middle.length, lessThan(100));
      expect(middle.map(lineIndex).reduce(math.min), greaterThan(900));
      expect(middle.map(lineIndex).reduce(math.max), lessThan(1100));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('the header identifies the language and exposes both actions', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpCode(
      tester,
      'print("hello")',
      language: 'py',
      highlighter: _FakeHighlighter(),
    );

    expect(find.text('Python'), findsOneWidget);
    final wrap = tester.getSemantics(find.bySemanticsLabel('Wrap long lines'));
    final copy = tester.getSemantics(find.bySemanticsLabel('Copy code'));
    expect(wrap.label, 'Wrap long lines');
    expect(wrap.flagsCollection.isButton, isTrue);
    expect(wrap.flagsCollection.isToggled, isNot(Tristate.none));
    expect(copy.label, 'Copy code');
    expect(copy.flagsCollection.isButton, isTrue);
    semantics.dispose();
  });

  testWidgets('syntax foreground and search ground survive together', (
    tester,
  ) async {
    final highlighter = _FakeHighlighter(
      result: const CodeHighlighting([
        CodeHighlightToken(
          start: 0,
          end: 11,
          role: CodeTokenRole.string,
          foreground: '#005cc5',
        ),
      ]),
    );
    await pumpCode(
      tester,
      'hello world',
      language: 'py',
      highlighter: highlighter,
      matches: const [TextMatch(start: 6, end: 11, excerpt: 'hello world')],
      activeMatch: 0,
    );

    final children = (sourceText(tester).textSpan! as TextSpan).children!
        .cast<TextSpan>();
    expect(children.map((span) => span.text).join(), 'hello world');
    final match = children.singleWhere((span) => span.text == 'world');
    expect(match.style!.color, isNotNull);
    expect(
      match.style!.backgroundColor,
      BuiltInThemes.paper.palette.accentSoft,
    );
  });

  testWidgets('a failed contributor leaves exact plain code visible', (
    tester,
  ) async {
    const source = 'git log --oneline "HEAD"...';
    await pumpCode(
      tester,
      source,
      language: 'broken',
      highlighter: _FakeHighlighter(throws: true),
    );

    expect(sourceText(tester).textSpan!.toPlainText(), source);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the same contributor reaches code nested inside a quotation', (
    tester,
  ) async {
    final highlighter = _FakeHighlighter();
    await pumpCode(
      tester,
      'nested',
      highlighter: highlighter,
      content: const DocumentContent([
        QuoteBlock([CodeBlock(code: 'nested', language: 'py')]),
      ]),
    );

    expect(highlighter.calls, 1);
    expect(find.text('Python'), findsOneWidget);
  });

  testWidgets('a short block fills its column without a scroll extent', (
    tester,
  ) async {
    await pumpCode(tester, 'ok');
    expect(horizontalPosition(tester).maxScrollExtent, 0);
    expect(
      tester.getSize(find.byType(ReadableCodeBlock)).width,
      greaterThan(300),
    );
  });

  testWidgets(
    'source lines stay compact while the complete surface returns to the prose rhythm',
    (tester) async {
      await pumpCode(tester, 'first line\n$_longLine\nthird line', width: 360);

      void expectRhythm() {
        final block = tester.widget<ReadableCodeBlock>(
          find.byType(ReadableCodeBlock),
        );
        final style = sourceText(tester).style!;
        final sourceLine = style.fontSize! * style.height!;
        expect(sourceLine, closeTo(22, 0.001));
        expect(sourceLine, lessThan(block.beat));

        final surface = tester.getSize(find.byType(ReadableCodeBlock)).height;
        expect(
          surface / block.beat,
          closeTo((surface / block.beat).roundToDouble(), 0.001),
        );
      }

      expectRhythm();
      await tester.tap(find.byKey(const ValueKey('code-wrap')));
      await tester.pump();
      expectRhythm();
    },
  );

  testWidgets('the body recedes on dark and comes forward on light', (
    tester,
  ) async {
    for (final theme in BuiltInThemes.all) {
      await pumpCode(tester, 'const value = 42;', readerTheme: theme);
      final header =
          (tester
                      .widget<Container>(
                        find.byKey(const ValueKey('code-block-surface')),
                      )
                      .decoration
                  as BoxDecoration)
              .color!;
      final body = tester
          .widget<ColoredBox>(find.byKey(const ValueKey('code-body-surface')))
          .color;
      if (theme.isDark) {
        expect(
          body.computeLuminance(),
          lessThan(header.computeLuminance()),
          reason: theme.name,
        );
      } else {
        expect(
          body.computeLuminance(),
          greaterThan(header.computeLuminance()),
          reason: theme.name,
        );
      }
    }
  });

  testWidgets('syntax suggestions stay legible on every built-in code body', (
    tester,
  ) async {
    for (final theme in BuiltInThemes.all) {
      final highlighter = _FakeHighlighter(
        result: CodeHighlighting([
          CodeHighlightToken(
            start: 0,
            end: 6,
            role: CodeTokenRole.keyword,
            foreground: theme.isDark ? '#000000' : '#ffffff',
          ),
        ]),
      );
      await pumpCode(
        tester,
        'unsafe',
        language: 'dart',
        highlighter: highlighter,
        readerTheme: theme,
      );

      final token = (sourceText(tester).textSpan! as TextSpan).children!
          .cast<TextSpan>()
          .single;
      final body = tester
          .widget<ColoredBox>(find.byKey(const ValueKey('code-body-surface')))
          .color;
      expect(
        ThemePalette.contrastRatio(token.style!.color!, body),
        greaterThanOrEqualTo(ThemePalette.minimumTextContrast),
        reason: theme.name,
      );
    }
  });
}
