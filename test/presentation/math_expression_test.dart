import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:katex/katex.dart';
import 'package:visualmd/api/render/document_view.dart';
import 'package:visualmd/api/render/reading_theme.dart';
import 'package:visualmd/api/theme/library_theme.dart';
import 'package:visualmd/api/widgets/math_expression.dart';
import 'package:visualmd/domain/reading/content/block.dart';
import 'package:visualmd/domain/reading/content/document_content.dart';
import 'package:visualmd/domain/reading/content/inline.dart';
import 'package:visualmd/presentation/theme/built_in_themes.dart';
import 'package:visualmd/presentation/theme/reading_scale.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ReadingTheme renderedTheme;

  Future<void> pumpDocument(
    WidgetTester tester,
    List<Block> blocks, {
    double width = 900,
    TextScaler textScaler = TextScaler.noScaling,
    bool dark = false,
    bool reduceMotion = false,
  }) async {
    tester.view.physicalSize = Size(width, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: libraryTheme(
          dark ? BuiltInThemes.lamplight : BuiltInThemes.paper,
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: textScaler, disableAnimations: reduceMotion),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Builder(
              builder: (context) {
                renderedTheme = ReadingTheme.of(
                  context,
                  ReadingScale.comfortable,
                );
                return DocumentView(
                  content: DocumentContent(blocks),
                  theme: renderedTheme,
                  anchorKeys: {},
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('inline equations keep their baseline and authored source', (
    tester,
  ) async {
    await pumpDocument(tester, [
      const ParagraphBlock([
        TextRun('Energy follows '),
        MathRun(r'E = mc^2'),
        TextRun('.'),
      ]),
    ]);

    final text = tester.widget<Text>(find.byType(Text).first);
    final root = text.textSpan! as TextSpan;
    final equation = root.children!.whereType<MathInlineSpan>().single;

    expect(root.toPlainText(), r'Energy follows E = mc^2.');
    expect(equation.alignment, PlaceholderAlignment.baseline);
    expect(equation.baseline, TextBaseline.alphabetic);
  });

  testWidgets('research notation is typeset instead of exposed as source', (
    tester,
  ) async {
    const attention = MathBlock(
      r'\operatorname{Attention}(Q,K,V)=\operatorname{softmax}'
      r'\left(\frac{QK^{\mathsf T}}{\sqrt{d_k}}\right)V\tag{1}',
    );
    const multiHead = MathBlock(
      r'\begin{aligned}\operatorname{MultiHead}(Q,K,V)&='
      r'\operatorname{Concat}(\operatorname{head}_1,\ldots,'
      r'\operatorname{head}_h)W^O\\\operatorname{head}_i&='
      r'\operatorname{Attention}(QW_i^Q,KW_i^K,VW_i^V)\end{aligned}',
    );

    await pumpDocument(tester, [attention, multiHead]);

    expect(find.byKey(const ValueKey('math-equation-body')), findsNWidgets(2));
    expect(find.byKey(const ValueKey('math-error-source')), findsNothing);
  });

  testWidgets('a display tag remains visible at the equation edge', (
    tester,
  ) async {
    await pumpDocument(tester, const [
      MathBlock(r'E = mc^2\tag{1}'),
      MathBlock(r'F = ma\tag*{Newton}'),
    ]);

    final tags = tester
        .widgetList<Math>(
          find.descendant(
            of: find.byKey(const ValueKey('math-equation-tag')),
            matching: find.byType(Math),
          ),
        )
        .map((math) => math.tex)
        .toList();
    expect(tags, ['(1)', 'Newton']);

    final equation = tester.getRect(
      find.byKey(const ValueKey('math-equation-body')).first,
    );
    final tag = tester.getRect(
      find.byKey(const ValueKey('math-equation-tag')).first,
    );
    expect(tag.center.dx, greaterThan(equation.center.dx));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a malformed equation remains quietly readable', (tester) async {
    await pumpDocument(tester, const [MathBlock(r'\frac{unclosed')]);

    expect(find.byKey(const ValueKey('math-error-source')), findsOneWidget);
    expect(find.text(r'\frac{unclosed'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('assistive technology receives the authored equation', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpDocument(tester, const [MathBlock(r'E = mc^2')]);

    expect(find.bySemanticsLabel(r'Equation in TeX: E = mc^2'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('wide mathematics scrolls locally without widening the page', (
    tester,
  ) async {
    await pumpDocument(tester, const [
      MathBlock(
        r'\begin{bmatrix}'
        r'a_{11}&a_{12}&a_{13}&a_{14}&a_{15}&a_{16}&a_{17}&a_{18}&a_{19}&a_{20}\\'
        r'b_{11}&b_{12}&b_{13}&b_{14}&b_{15}&b_{16}&b_{17}&b_{18}&b_{19}&b_{20}'
        r'\end{bmatrix}',
      ),
    ], width: 420);

    final scroll = tester.state<ScrollableState>(
      find.descendant(
        of: find.byKey(const ValueKey('math-horizontal-scroll')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(scroll.position.maxScrollExtent, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('display mathematics returns following prose to the grid', (
    tester,
  ) async {
    await pumpDocument(tester, const [
      ParagraphBlock([TextRun('Before.')]),
      MathBlock(r'\sum_{i=1}^{n} i = \frac{n(n+1)}{2}'),
      ParagraphBlock([TextRun('After.')]),
    ]);

    final before = tester.getTopLeft(find.text('Before.')).dy;
    final after = tester.getTopLeft(find.text('After.')).dy;
    final beats = (after - before) / renderedTheme.baseline;
    expect(beats, closeTo(beats.roundToDouble(), 0.01));
  });

  testWidgets('the hover action copies the authoritative TeX', (tester) async {
    final clipboard = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard.add((call.arguments as Map)['text'] as String);
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
    await pumpDocument(tester, const [MathBlock(r'\alpha + \beta')]);

    expect(
      tester
          .widget<AnimatedOpacity>(
            find.byKey(const ValueKey('math-copy-visibility')),
          )
          .opacity,
      0,
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byType(ReadableMathBlock)));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<AnimatedOpacity>(
            find.byKey(const ValueKey('math-copy-visibility')),
          )
          .opacity,
      1,
    );
    await tester.tap(find.byKey(const ValueKey('math-copy')));
    await mouse.removePointer();

    expect(clipboard, [r'\alpha + \beta']);
  });

  testWidgets('keyboard focus reveals the equation copy action', (
    tester,
  ) async {
    await pumpDocument(tester, const [MathBlock(r'E = mc^2')]);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<AnimatedOpacity>(
            find.byKey(const ValueKey('math-copy-visibility')),
          )
          .opacity,
      1,
    );
    expect(
      Focus.of(tester.element(find.byKey(const ValueKey('math-copy'))))
          .hasFocus,
      isTrue,
    );
  });

  testWidgets('Reduce Motion removes the equation-action fade', (tester) async {
    await pumpDocument(tester, const [
      MathBlock(r'E = mc^2'),
    ], reduceMotion: true);

    final visibility = tester.widget<AnimatedOpacity>(
      find.byKey(const ValueKey('math-copy-visibility')),
    );
    expect(visibility.duration, Duration.zero);
  });

  testWidgets('math follows accessibility scaling and the active ink', (
    tester,
  ) async {
    await pumpDocument(
      tester,
      const [MathBlock(r'x^2')],
      textScaler: const TextScaler.linear(1.5),
      dark: true,
    );

    final math = tester.widget<Math>(find.byType(Math));
    expect(math.fontSize, closeTo(renderedTheme.displayMathSize, 0.001));
    expect(math.color, renderedTheme.palette.ink);
    expect(
      renderedTheme.displayMathSize * 0.431,
      closeTo(
        renderedTheme.textScaler.scale(ReadingScale.comfortable.base) * 0.55,
        0.001,
      ),
    );
  });
}
