import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/api/theme/library_theme.dart';
import 'package:visualmd/api/widgets/theme_picker.dart';
import 'package:visualmd/presentation/theme/built_in_themes.dart';
import 'package:visualmd/presentation/theme/reading_scale.dart';
import 'package:visualmd/presentation/theme/theme_choice.dart';
import 'package:visualmd/presentation/theme/theme_registry.dart';

void main() {
  late ThemeRegistry registry;
  late List<ThemeChoice> chosen;
  late List<ParagraphMarking> marked;

  setUp(() {
    registry = ThemeRegistry();
    chosen = [];
    marked = [];
  });

  Future<void> pumpPicker(
    WidgetTester tester, {
    bool reduceMotion = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: libraryTheme(BuiltInThemes.paper),
        builder: (context, child) => MediaQuery(
          // Keep the real size; only the motion preference changes.
          data: MediaQuery.of(context)
              .copyWith(disableAnimations: reduceMotion),
          child: child!,
        ),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topRight,
            child: ThemePicker(
              registry: registry,
              choice: registry.systemPair,
              onChoose: chosen.add,
              marking: ParagraphMarking.spaced,
              onMark: marked.add,
              themesLocation: '/somewhere/themes',
            ),
          ),
        ),
      ),
    );
  }

  /// The opacity the stagger gives a row, nearest wrapper first.
  double opacityOf(WidgetTester tester, String label) => tester
      .widget<Opacity>(
        find
            .ancestor(of: find.text(label), matching: find.byType(Opacity))
            .first,
      )
      .opacity;

  testWidgets('opens on tap and lists every theme, grouped by brightness', (
    tester,
  ) async {
    await pumpPicker(tester);
    expect(find.text('Catppuccin Mocha'), findsNothing);

    await tester.tap(find.byType(ThemePicker));
    await tester.pumpAndSettle();

    expect(find.text('Follow system'), findsOneWidget);
    expect(find.text('LIGHT'), findsOneWidget);
    expect(find.text('DARK'), findsOneWidget);
    for (final theme in BuiltInThemes.all) {
      expect(find.text(theme.name), findsOneWidget, reason: theme.id);
    }
    expect(find.textContaining('/somewhere/themes'), findsOneWidget);
  });

  testWidgets('the menu is clickable where it is drawn', (tester) async {
    await pumpPicker(tester);
    await tester.tap(find.byType(ThemePicker));
    await tester.pumpAndSettle();

    // A menu that paints in one place and hit-tests in another is the bug
    // this guards: every row must be reachable by a real pointer.
    for (final theme in BuiltInThemes.all) {
      expect(
        find.text(theme.name).hitTestable(),
        findsOneWidget,
        reason: theme.id,
      );
    }
  });

  testWidgets('opens on the press, not on the release', (tester) async {
    await pumpPicker(tester);

    final press = await tester.startGesture(
      tester.getCenter(find.byType(ThemePicker)),
    );
    await tester.pumpAndSettle();
    // Still holding the button down — the menu must already be there.
    expect(find.text('Follow system'), findsOneWidget);

    await press.up();
    await tester.pumpAndSettle();
    expect(
      find.text('Follow system'),
      findsOneWidget,
      reason: 'the release must not close it',
    );
  });

  testWidgets('pressing the trigger again closes it', (tester) async {
    await pumpPicker(tester);
    await tester.tap(find.byType(ThemePicker));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ThemePicker), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Follow system'), findsNothing);
    expect(chosen, isEmpty);
  });

  testWidgets('rows arrive staggered: later rows lag earlier ones', (
    tester,
  ) async {
    await pumpPicker(tester);
    await tester.tap(find.byType(ThemePicker));
    await tester.pump(); // the frame the menu opens on

    await tester.pump(const Duration(milliseconds: 70));
    final first = opacityOf(tester, 'Follow system');
    final last = opacityOf(tester, BuiltInThemes.all.last.name);
    expect(
      first,
      greaterThan(last),
      reason: 'the top row should lead the bottom one',
    );
    expect(
      last,
      lessThan(1.0),
      reason: 'the bottom row should still be arriving',
    );

    await tester.pumpAndSettle();
    expect(opacityOf(tester, BuiltInThemes.all.last.name), 1.0);
  });

  testWidgets('choosing a theme reports it and closes the menu', (
    tester,
  ) async {
    await pumpPicker(tester);
    await tester.tap(find.byType(ThemePicker));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nord'));
    await tester.pumpAndSettle();

    expect(chosen, [const FixedTheme('nord')]);
    expect(find.text('Nord'), findsNothing);
  });

  testWidgets('escape and tapping away both dismiss it without choosing', (
    tester,
  ) async {
    await pumpPicker(tester);
    await tester.tap(find.byType(ThemePicker));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Follow system'), findsNothing);

    await tester.tap(find.byType(ThemePicker));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(20, 400));
    await tester.pumpAndSettle();
    expect(find.text('Follow system'), findsNothing);
    expect(chosen, isEmpty);
  });

  testWidgets('reduce motion opens it at once, fully visible', (tester) async {
    await pumpPicker(tester, reduceMotion: true);
    await tester.tap(find.byType(ThemePicker));
    await tester.pump();

    expect(find.text('Follow system'), findsOneWidget);
    expect(opacityOf(tester, 'Follow system'), 1.0);
    expect(find.text('Nord').hitTestable(), findsOneWidget);
  });

  testWidgets('the menu also chooses how paragraphs are marked', (
    tester,
  ) async {
    await pumpPicker(tester);
    await tester.tap(find.byType(ThemePicker));
    await tester.pumpAndSettle();

    expect(find.text('PARAGRAPHS'), findsOneWidget);
    // The menu is taller than this window, so the row has to be brought up
    // before it can be pressed.
    await tester.ensureVisible(find.text('Indented, set solid'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Indented, set solid'));
    await tester.pumpAndSettle();

    expect(marked, [ParagraphMarking.indented]);
    expect(
      find.text('Indented, set solid'),
      findsNothing,
      reason: 'and the menu closes',
    );
  });
}
