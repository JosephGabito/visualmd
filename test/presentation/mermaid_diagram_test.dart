import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/api/theme/library_theme.dart';
import 'package:visualmd/api/widgets/mermaid_diagram.dart';
import 'package:visualmd/application/ports/mermaid_renderer.dart';
import 'package:visualmd/presentation/theme/built_in_themes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const palette = MermaidPalette(
    canvas: '#fff',
    surface: '#f5f2e8',
    text: '#222',
    subtleText: '#777',
    border: '#ddd',
    line: '#777',
    accent: '#b65f2a',
    dark: false,
  );

  Future<void> pumpDiagram(
    WidgetTester tester,
    MermaidRenderer renderer, {
    String source = 'flowchart LR\n  Read --> Understand',
    bool reduceMotion = false,
  }) async {
    tester.view.physicalSize = const Size(900, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: libraryTheme(BuiltInThemes.paper),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(disableAnimations: reduceMotion),
          child: child!,
        ),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 700,
              child: ReadableMermaidDiagram(
                source: source,
                renderer: renderer,
                palette: palette,
                beat: 32,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the fitted diagram has a bounded quiet reading state', (
    tester,
  ) async {
    final renderer = _FakeRenderer();
    await pumpDiagram(tester, renderer);

    final viewport = tester.getSize(
      find.byKey(const ValueKey('mermaid-viewport')),
    );
    final controller = tester
        .widget<InteractiveViewer>(
          find.byKey(const ValueKey('mermaid-interactive')),
        )
        .transformationController!;

    expect(viewport.height, inInclusiveRange(32 * 8, 32 * 18));
    expect(controller.value.getMaxScaleOnAxis(), closeTo(1.75, 0.01));
    expect(renderer.calls, 1);
  });

  testWidgets('zoom, drag, and fit operate on one diagram model', (
    tester,
  ) async {
    await pumpDiagram(tester, _FakeRenderer());
    final viewer = find.byKey(const ValueKey('mermaid-interactive'));
    final controller = tester
        .widget<InteractiveViewer>(viewer)
        .transformationController!;
    final fitted = Matrix4.copy(controller.value);

    await tester.tap(find.byKey(const ValueKey('mermaid-zoom-in')));
    await tester.pump();
    expect(controller.value.getMaxScaleOnAxis(), greaterThan(1.75));

    final beforeDrag = Matrix4.copy(controller.value);
    await tester.drag(viewer, const Offset(70, 45));
    await tester.pump();
    expect(controller.value, isNot(equals(beforeDrag)));

    await tester.tap(find.byKey(const ValueKey('mermaid-reset')));
    await tester.pump();
    expect(controller.value, equals(fitted));

    await tester.tap(find.byKey(const ValueKey('mermaid-zoom-in')));
    await tester.fling(viewer, const Offset(2000, 2000), 10000);
    await tester.pumpAndSettle();
    final reachable = MatrixUtils.transformRect(
      controller.value,
      const Rect.fromLTWH(0, 0, 400, 200),
    );
    expect(reachable.right, greaterThanOrEqualTo(105));
    expect(reachable.bottom, greaterThanOrEqualTo(105));
  });

  testWidgets(
    'full screen explorer accepts both standard cancellation commands',
    (tester) async {
      await pumpDiagram(tester, _FakeRenderer());

      await tester.tap(find.byKey(const ValueKey('mermaid-fullscreen')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('mermaid-surface')), findsNWidgets(2));
      expect(
        find.byKey(const ValueKey('mermaid-close-fullscreen')),
        findsOneWidget,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('mermaid-surface')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('mermaid-fullscreen')));
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.period);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('mermaid-surface')), findsOneWidget);
    },
  );

  testWidgets('Reduce Motion opens the full-screen explorer without a fade', (
    tester,
  ) async {
    await pumpDiagram(tester, _FakeRenderer(), reduceMotion: true);

    await tester.tap(find.byKey(const ValueKey('mermaid-fullscreen')));
    await tester.pump();

    final fullScreen = find.byKey(const ValueKey('mermaid-close-fullscreen'));
    expect(fullScreen, findsOneWidget);
    expect(
      ModalRoute.of(tester.element(fullScreen))!.transitionDuration,
      Duration.zero,
    );
  });

  testWidgets('copy preserves the exact authored Mermaid source', (
    tester,
  ) async {
    const source = 'sequenceDiagram\n  Alice->>Bob: Read  ';
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

    await pumpDiagram(tester, _FakeRenderer(), source: source);
    await tester.tap(find.byKey(const ValueKey('mermaid-copy')));
    await tester.pump();

    expect(copied, source);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });

  testWidgets('rendering failure leaves the exact source readable', (
    tester,
  ) async {
    const source = 'not a diagram\n  but still authored';
    await pumpDiagram(
      tester,
      _FakeRenderer(failure: StateError('invalid')),
      source: source,
    );

    expect(find.byKey(const ValueKey('mermaid-fallback')), findsOneWidget);
    expect(find.text(source), findsOneWidget);
    expect(find.byKey(const ValueKey('mermaid-svg')), findsNothing);
  });

  testWidgets('rebuilds do not rerun layout while source changes do', (
    tester,
  ) async {
    final renderer = _FakeRenderer();
    final source = ValueNotifier('flowchart LR\n  A --> B');
    addTearDown(source.dispose);
    tester.view.physicalSize = const Size(900, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: libraryTheme(BuiltInThemes.paper),
        home: ValueListenableBuilder(
          valueListenable: source,
          builder: (context, value, child) => ReadableMermaidDiagram(
            source: value,
            renderer: renderer,
            palette: palette,
            beat: 32,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(renderer.calls, 1);

    await tester.pump();
    expect(renderer.calls, 1);

    source.value = 'flowchart LR\n  A --> C';
    await tester.pumpAndSettle();
    expect(renderer.calls, 2);
  });

  testWidgets('authored accessibility text names the rendered image', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpDiagram(tester, _FakeRenderer());

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Transformer model architecture' &&
            widget.properties.value ==
                'Inputs move through an encoder and decoder.',
      ),
      findsOneWidget,
    );
    semantics.dispose();
  });
}

final class _FakeRenderer implements MermaidRenderer {
  _FakeRenderer({this.failure});

  final Object? failure;
  var calls = 0;

  @override
  Future<MermaidRendering> render({
    required String source,
    required MermaidPalette palette,
  }) async {
    calls++;
    if (failure case final failure?) throw failure;
    return const MermaidRendering(
      svg:
          '<svg viewBox="0 0 400 200" '
          'xmlns="http://www.w3.org/2000/svg">'
          '<rect width="400" height="200" fill="#eee" />'
          '</svg>',
      title: 'Transformer model architecture',
      description: 'Inputs move through an encoder and decoder.',
    );
  }
}
