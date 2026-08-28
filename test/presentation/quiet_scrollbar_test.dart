import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/api/theme/library_theme.dart';
import 'package:visualmd/api/widgets/quiet_scrollbar.dart';
import 'package:visualmd/application/ports/document_viewport_geometry.dart';
import 'package:visualmd/infrastructure/viewport/quiet_document_viewport_geometry.dart';
import 'package:visualmd/presentation/theme/built_in_themes.dart';

void main() {
  const factory = QuietDocumentViewportGeometryFactory();
  const thumbKey = ValueKey('quiet-scrollbar-thumb');

  testWidgets(
    'a streamed tail cannot resize or move a visible scrollbar thumb',
    (tester) async {
      tester.view.physicalSize = const Size(800, 500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final controller = ScrollController();
      final epochController = QuietScrollbarController();
      addTearDown(controller.dispose);

      Future<void> show(int items) => tester.pumpWidget(
        MaterialApp(
          theme: libraryTheme(BuiltInThemes.paper),
          home: Scaffold(
            body: QuietScrollbar(
              controller: controller,
              geometryFactory: factory,
              epochController: epochController,
              fadeDelay: const Duration(seconds: 10),
              child: ListView.builder(
                controller: controller,
                itemExtent: 40,
                itemCount: items,
                itemBuilder: (_, index) => Text('Block $index'),
              ),
            ),
          ),
        ),
      );

      await show(100);
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(const Offset(400, 300));
      await gesture.moveBy(const Offset(0, -120));
      await tester.pump();
      final before = tester.getRect(find.byKey(thumbKey));

      epochController.absorb(
        const DocumentExtentCorrection(
          contentExtentDelta: 80,
          scrollOffsetDelta: 80,
        ),
      );
      controller.jumpTo(controller.offset + 80);
      await tester.pump();
      final corrected = tester.getRect(find.byKey(thumbKey));

      expect(corrected.top, closeTo(before.top, 0.01));
      expect(corrected.height, closeTo(before.height, 0.01));

      await show(500);
      await tester.pump();
      final after = tester.getRect(find.byKey(thumbKey));

      expect(after.top, closeTo(before.top, 0.01));
      expect(after.height, closeTo(before.height, 0.01));

      await gesture.up();
      final continuedGesture = await tester.startGesture(
        const Offset(400, 300),
      );
      await continuedGesture.moveBy(const Offset(0, -80));
      await tester.pump();
      final moved = tester.getRect(find.byKey(thumbKey));
      expect(moved.top, greaterThan(after.top));
      expect(moved.height, closeTo(after.height, 0.01));
      await continuedGesture.up();
    },
  );

  testWidgets('dragging the frozen thumb controls the live reader position', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: libraryTheme(BuiltInThemes.paper),
        home: Scaffold(
          body: QuietScrollbar(
            controller: controller,
            geometryFactory: factory,
            fadeDelay: const Duration(seconds: 10),
            child: ListView.builder(
              controller: controller,
              itemExtent: 40,
              itemCount: 200,
              itemBuilder: (_, index) => Text('Block $index'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -100));
    await tester.pump();
    final thumb = tester.getRect(find.byKey(thumbKey));
    final before = controller.position.pixels;

    await tester.dragFrom(thumb.center, const Offset(0, 100));
    await tester.pump();

    expect(controller.position.pixels, greaterThan(before));
  });

  testWidgets('Reduce Motion shows the quiet thumb without a fade', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: libraryTheme(BuiltInThemes.paper),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(
          body: QuietScrollbar(
            controller: controller,
            geometryFactory: factory,
            child: ListView.builder(
              controller: controller,
              itemExtent: 40,
              itemCount: 200,
              itemBuilder: (_, index) => Text('Block $index'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -100));
    await tester.pump();

    final fade = tester.widget<FadeTransition>(
      find.descendant(
        of: find.byKey(thumbKey),
        matching: find.byType(FadeTransition),
      ),
    );
    final opacity = fade.opacity as AnimationController;
    expect(opacity.duration, Duration.zero);
    expect(opacity.value, 1);
    expect(controller.position.pixels, greaterThan(0));

    await tester.pump(const Duration(milliseconds: 650));
    await tester.pump();
    expect(find.byKey(thumbKey), findsNothing);
  });
}
