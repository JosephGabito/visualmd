import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/api/theme/library_theme.dart';
import 'package:visualmd/api/widgets/welcome_view.dart';
import 'package:visualmd/presentation/theme/built_in_themes.dart';

void main() {
  Future<void> pumpWelcome(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: libraryTheme(BuiltInThemes.paper),
        home: Scaffold(
          body: WelcomeView(
            opening: false,
            error: null,
            onOpenFolder: () {},
            onOpenSample: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the welcome composition fits the desktop launch viewport', (
    tester,
  ) async {
    await pumpWelcome(tester, const Size(1280, 716));

    expect(tester.takeException(), isNull);
    expect(find.text('Nothing leaves your machine.'), findsOneWidget);
    expect(
      tester.getBottomRight(find.text('Nothing leaves your machine.')).dy,
      lessThanOrEqualTo(716),
    );
  });

  testWidgets('a deliberately short window scrolls instead of overflowing', (
    tester,
  ) async {
    await pumpWelcome(tester, const Size(800, 480));

    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -160),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nothing leaves your machine.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
