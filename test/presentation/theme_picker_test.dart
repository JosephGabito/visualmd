import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/api/theme/library_theme.dart';
import 'package:visualmd/api/widgets/anchored_menu.dart';
import 'package:visualmd/api/widgets/theme_picker.dart';
import 'package:visualmd/presentation/theme/built_in_themes.dart';
import 'package:visualmd/presentation/theme/reading_mode.dart';
import 'package:visualmd/presentation/theme/reading_scale.dart';
import 'package:visualmd/presentation/theme/theme_choice.dart';
import 'package:visualmd/presentation/theme/theme_registry.dart';

void main() {
  late ThemeRegistry registry;
  late List<ThemeChoice> chosen;
  late List<ReadingMode> modes;
  late List<ParagraphMarking> marked;
  late int themeFolderOpens;

  setUp(() {
    registry = ThemeRegistry();
    chosen = [];
    modes = [];
    marked = [];
    themeFolderOpens = 0;
  });

  Future<void> pumpPicker(
    WidgetTester tester, {
    bool reduceMotion = false,
    Brightness brightness = Brightness.light,
    AnchoredMenuController? controller,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: libraryTheme(BuiltInThemes.paper),
        builder: (context, child) => MediaQuery(
          // Keep the real size; only the motion preference changes.
          data: MediaQuery.of(context).copyWith(
            disableAnimations: reduceMotion,
            platformBrightness: brightness,
          ),
          child: child!,
        ),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topRight,
            child: ThemePicker(
              menuController: controller,
              registry: registry,
              choice: registry.systemPair,
              onChoose: chosen.add,
              mode: ReadingMode.serif,
              onMode: modes.add,
              marking: ParagraphMarking.spaced,
              onMark: marked.add,
              onOpenThemesFolder: () async {
                themeFolderOpens++;
              },
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('an external command opens the existing appearance menu', (
    tester,
  ) async {
    final controller = AnchoredMenuController();
    addTearDown(controller.dispose);
    await pumpPicker(tester, controller: controller);

    controller.open();
    await tester.pumpAndSettle();

    expect(find.text('Follow system'), findsOneWidget);
    expect(find.text('Serif'), findsOneWidget);
    expect(find.text('Sans'), findsOneWidget);
  });

  /// The opacity the stagger gives a row, nearest wrapper first.
  double opacityOf(WidgetTester tester, String label) => tester
      .widget<Opacity>(
        find
            .ancestor(of: find.text(label), matching: find.byType(Opacity))
            .first,
      )
      .opacity;

  testWidgets('opens on tap and lists each family once', (tester) async {
    await pumpPicker(tester);
    expect(find.text('Catppuccin Mocha'), findsNothing);

    await tester.tap(find.byType(ThemePicker));
    await tester.pumpAndSettle();

    expect(find.text('Follow system'), findsOneWidget);
    expect(find.text('READING MODE'), findsOneWidget);
    expect(find.text('Serif'), findsOneWidget);
    expect(find.text('Sans'), findsOneWidget);
    expect(find.text('THEMES'), findsOneWidget);
    expect(find.text('MORE THEMES'), findsOneWidget);
    expect(find.text('LIGHT'), findsOneWidget);
    expect(find.text('DARK'), findsOneWidget);
    for (final family in BuiltInThemes.families) {
      expect(find.text(family.name), findsOneWidget);
    }
    expect(find.text('Paper'), findsOneWidget);
    expect(find.text('Lamplight'), findsOneWidget);
    expect(find.text('Nord'), findsOneWidget);
    expect(find.text('Codex Light'), findsNothing);
    expect(find.text('Codex Dark'), findsNothing);
    expect(find.text('Open themes folder'), findsOneWidget);
  });

  testWidgets('a paired family follows the system after it is chosen', (
    tester,
  ) async {
    await pumpPicker(tester);
    await tester.tap(find.byType(ThemePicker));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Codex'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Codex'));
    await tester.pumpAndSettle();

    expect(chosen, [
      const FollowSystem(light: 'codex-light', dark: 'codex-dark'),
    ]);
    expect(find.text('Codex'), findsNothing);
  });

  testWidgets('a family without a dark member is absent on a dark system', (
    tester,
  ) async {
    await pumpPicker(tester, brightness: Brightness.dark);
    await tester.tap(find.byType(ThemePicker));
    await tester.pumpAndSettle();

    expect(find.text('Codex'), findsOneWidget);
    expect(find.text('Proof'), findsNothing);
  });

  testWidgets(
    'keyboard entry names the selected row and returns focus after dismissal',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpPicker(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      final row = tester.getSemantics(find.bySemanticsLabel('Serif'));
      expect(row.flagsCollection.isButton, isTrue);
      expect(row.flagsCollection.isSelected, Tristate.isTrue);

      final focusedContainer = tester.widget<AnimatedContainer>(
        find
            .ancestor(
              of: find.text('Serif'),
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );
      final focusDecoration = focusedContainer.decoration! as BoxDecoration;
      expect(
        focusDecoration.color,
        isNotNull,
        reason: 'keyboard focus uses the same quiet ground as pointer hover',
      );
      expect(
        focusDecoration.border,
        isNull,
        reason: 'a menu row does not add a second rounded outline signal',
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Sans'))
            .flagsCollection
            .isFocused,
        Tristate.isTrue,
        reason: 'arrow keys traverse the menu without requiring Tab',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(modes, [ReadingMode.serif]);
      expect(find.text('Follow system'), findsNothing);

      // Closing restores the trigger, so keyboard users can reopen without
      // traversing the entire reader again.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Follow system'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Follow system'), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Follow system'), findsOneWidget);
      semantics.dispose();
    },
  );

  testWidgets('the menu is clickable where it is drawn', (tester) async {
    await pumpPicker(tester);
    await tester.tap(find.byType(ThemePicker));
    await tester.pumpAndSettle();

    // A menu that paints in one place and hit-tests in another is the bug
    // this guards: every row must be reachable by a real pointer.
    for (final family in BuiltInThemes.families) {
      await tester.ensureVisible(find.text(family.name));
      await tester.pumpAndSettle();
      expect(
        find.text(family.name).hitTestable(),
        findsOneWidget,
        reason: family.name,
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
    final last = opacityOf(tester, BuiltInThemes.families.last.name);
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
    expect(opacityOf(tester, BuiltInThemes.families.last.name), 1.0);
  });

  testWidgets('choosing a theme reports it and closes the menu', (
    tester,
  ) async {
    await pumpPicker(tester);
    await tester.tap(find.byType(ThemePicker));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Nord'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nord'));
    await tester.pumpAndSettle();

    expect(chosen, [const FixedTheme('nord')]);
    expect(find.text('Nord'), findsNothing);
  });

  testWidgets('choosing a reading mode reports it and closes the menu', (
    tester,
  ) async {
    await pumpPicker(tester);
    await tester.tap(find.byType(ThemePicker));
    await tester.pumpAndSettle();

    expect(
      tester
          .getSemantics(find.bySemanticsLabel('Serif'))
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );
    await tester.tap(find.text('Sans'));
    await tester.pumpAndSettle();

    expect(modes, [ReadingMode.sans]);
    expect(find.text('Sans'), findsNothing, reason: 'and the menu closes');
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
    expect(find.text('Absolutely').hitTestable(), findsOneWidget);
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
    await tester.ensureVisible(find.text('Book-style indents'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Book-style indents'));
    await tester.pumpAndSettle();

    expect(marked, [ParagraphMarking.indented]);
    expect(
      find.text('Book-style indents'),
      findsNothing,
      reason: 'and the menu closes',
    );
  });

  testWidgets('the constrained menu keeps a visible scroll affordance', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpPicker(tester);

    await tester.tap(find.byType(ThemePicker));
    await tester.pumpAndSettle();

    expect(
      tester.widget<Scrollbar>(find.byType(Scrollbar)).thumbVisibility,
      isTrue,
    );
  });

  testWidgets('the theme folder action opens the platform location', (
    tester,
  ) async {
    await pumpPicker(tester);
    await tester.tap(find.byType(ThemePicker));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Open themes folder'));
    await tester.tap(find.text('Open themes folder'));
    await tester.pumpAndSettle();

    expect(themeFolderOpens, 1);
    expect(find.text('Open themes folder'), findsNothing);
  });

  testWidgets(
    'a skipped theme explains itself without sending readers to a console',
    (tester) async {
      registry = ThemeRegistry.fromDocuments(const [
        (origin: 'broken.json', json: '{"id":"oops","name":"Oops"}'),
      ]);
      await pumpPicker(tester);
      await tester.tap(find.byType(ThemePicker));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('broken.json skipped'));
      await tester.pumpAndSettle();

      expect(find.text('broken.json skipped'), findsOneWidget);
      expect(
        find.text('"brightness" must be a non-empty string'),
        findsOneWidget,
      );
      expect(find.text('Open themes folder'), findsOneWidget);
      expect(find.textContaining('console'), findsNothing);
    },
  );
}
