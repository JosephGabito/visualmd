import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/api/theme/library_theme.dart';
import 'package:visualmd/api/widgets/search_view.dart';
import 'package:visualmd/presentation/theme/theme_choice.dart';
import 'package:visualmd/presentation/theme/theme_registry.dart';

void main() {
  testWidgets(
    'the floating find surface paints its shadow behind opaque material',
    (tester) async {
      final registry = ThemeRegistry();
      final paper = registry.resolve(
        const FixedTheme('paper'),
        Brightness.light,
      );
      final controller = TextEditingController();
      final focus = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focus.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: libraryTheme(paper),
          home: Scaffold(
            body: Center(
              child: DocumentFindBar(
                controller: controller,
                focusNode: focus,
                onChanged: (_) {},
                onNext: () {},
                onPrevious: () {},
                onClose: () {},
                active: 0,
                total: 0,
                searching: false,
              ),
            ),
          ),
        ),
      );

      final decorated = tester.widget<Container>(
        find.descendant(
          of: find.byType(DocumentFindBar),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Container &&
                widget.decoration is BoxDecoration &&
                (widget.decoration! as BoxDecoration).boxShadow != null,
          ),
        ),
      );
      final decoration = decorated.decoration! as BoxDecoration;

      expect(decoration.color, isNotNull);
      expect(decoration.color!.a, 1);
      expect(decoration.boxShadow, isNotEmpty);
    },
  );

  testWidgets('document search exposes named fields and controls', (
    tester,
  ) async {
    final registry = ThemeRegistry();
    final paper = registry.resolve(const FixedTheme('paper'), Brightness.light);
    final controller = TextEditingController();
    final focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: libraryTheme(paper),
        home: Scaffold(
          body: DocumentFindBar(
            controller: controller,
            focusNode: focus,
            onChanged: (_) {},
            onNext: () {},
            onPrevious: () {},
            onClose: () {},
            active: 0,
            total: 1,
            searching: false,
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Find in this document'), findsWidgets);
    expect(find.bySemanticsLabel('Previous match  (⇧↩)'), findsOneWidget);
    expect(find.bySemanticsLabel('Next match  (↩)'), findsOneWidget);
    expect(find.bySemanticsLabel('Close  (Esc)'), findsOneWidget);
  });
}
