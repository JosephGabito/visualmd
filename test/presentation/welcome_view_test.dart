import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/api/theme/library_theme.dart';
import 'package:visualmd/api/widgets/welcome_view.dart';
import 'package:visualmd/presentation/theme/built_in_themes.dart';

void main() {
  Future<void> pumpWelcome(
    WidgetTester tester,
    Size size, {
    TargetPlatform platform = TargetPlatform.macOS,
    VoidCallback? onOpen,
    VoidCallback? onOpenWorkspace,
    VoidCallback? onOpenSample,
    bool opensMixedSources = true,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: libraryTheme(BuiltInThemes.paper).copyWith(platform: platform),
        home: Scaffold(
          body: WelcomeView(
            opening: false,
            error: null,
            onOpen: onOpen ?? () {},
            onOpenWorkspace: onOpenWorkspace ?? () {},
            onOpenSample: onOpenSample ?? () {},
            opensMixedSources: opensMixedSources,
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
    expect(find.text('Your files stay on your device.'), findsOneWidget);
    expect(
      tester.getBottomRight(find.text('Your files stay on your device.')).dy,
      lessThanOrEqualTo(716),
    );
  });

  testWidgets('the launcher presents three complete macOS commands', (
    tester,
  ) async {
    var opened = 0;
    var openedWorkspace = 0;
    var openedSample = 0;
    await pumpWelcome(
      tester,
      const Size(1280, 716),
      onOpen: () => opened++,
      onOpenWorkspace: () => openedWorkspace++,
      onOpenSample: () => openedSample++,
    );

    expect(find.text('A quiet place to read Markdown.'), findsOneWidget);
    expect(find.text('Open a Markdown file or folder'), findsOneWidget);
    expect(find.text('Restore a saved workspace'), findsOneWidget);
    expect(find.text('Explore a ready-made library'), findsOneWidget);
    expect(find.text('⌘O'), findsOneWidget);
    expect(find.text('⇧⌘O'), findsOneWidget);
    expect(find.text('⌥⌘O'), findsOneWidget);
    expect(find.byIcon(Icons.folder_open_outlined), findsOneWidget);
    expect(find.byIcon(Icons.grid_view_outlined), findsOneWidget);
    expect(find.byIcon(Icons.menu_book_outlined), findsOneWidget);

    await tester.tap(find.text('Open…'));
    await tester.tap(find.text('Open Workspace…'));
    await tester.tap(find.text('Open Sample Library'));

    expect((opened, openedWorkspace, openedSample), (1, 1, 1));
  });

  testWidgets('the elevated launch surface does not add a redundant border', (
    tester,
  ) async {
    await pumpWelcome(tester, const Size(1280, 716));

    final surface = tester.widget<Container>(
      find.byKey(const ValueKey('welcome-launch-surface')),
    );
    final decoration = surface.decoration! as BoxDecoration;
    expect(decoration.border, isNull);
    expect(decoration.boxShadow, isNotEmpty);
  });

  testWidgets('non-macOS commands use Ctrl labels and truthful open copy', (
    tester,
  ) async {
    await pumpWelcome(
      tester,
      const Size(1280, 716),
      platform: TargetPlatform.windows,
      opensMixedSources: false,
    );

    expect(find.text('Open a folder of Markdown files'), findsOneWidget);
    expect(find.text('Ctrl+O'), findsOneWidget);
    expect(find.text('Ctrl+Shift+O'), findsOneWidget);
    expect(find.text('Ctrl+Alt+O'), findsOneWidget);
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
    expect(find.text('Your files stay on your device.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
