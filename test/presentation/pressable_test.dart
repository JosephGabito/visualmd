import 'dart:ui' show SemanticsAction, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/api/widgets/pressable.dart';

void main() {
  Future<void> pumpPressable(
    WidgetTester tester, {
    required VoidCallback? onPress,
    String semanticLabel = 'Open theme choices',
    String? tooltip,
    bool? expanded,
    FocusNode? focusNode,
    bool activateOnPointerDown = false,
    Widget child = const SizedBox(
      width: 40,
      height: 40,
      child: Icon(Icons.palette_outlined, semanticLabel: 'Palette icon'),
    ),
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: Pressable(
            onPress: onPress,
            semanticLabel: semanticLabel,
            tooltip: tooltip,
            expanded: expanded,
            focusNode: focusNode,
            activateOnPointerDown: activateOnPointerDown,
            child: child,
          ),
        ),
      ),
    ),
  );

  testWidgets('an ordinary button activates on release inside', (tester) async {
    var activations = 0;
    await pumpPressable(tester, onPress: () => activations++);

    final pointer = await tester.startGesture(
      tester.getCenter(find.byType(Pressable)),
    );
    expect(activations, 0);

    await pointer.up();
    expect(activations, 1);
  });

  testWidgets('moving away before release cancels an ordinary button', (
    tester,
  ) async {
    var activations = 0;
    await pumpPressable(tester, onPress: () => activations++);

    final pointer = await tester.startGesture(
      tester.getCenter(find.byType(Pressable)),
    );
    await pointer.moveBy(const Offset(100, 100));
    await pointer.up();

    expect(activations, 0);
  });

  testWidgets('a menu trigger can explicitly activate on pointer down', (
    tester,
  ) async {
    var activations = 0;
    await pumpPressable(
      tester,
      onPress: () => activations++,
      activateOnPointerDown: true,
    );

    final pointer = await tester.startGesture(
      tester.getCenter(find.byType(Pressable)),
    );
    expect(activations, 1);
    await pointer.up();
    expect(activations, 1);
  });

  testWidgets('assistive technology receives one named button contract', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpPressable(
      tester,
      onPress: () {},
      expanded: true,
      tooltip: 'Choose a reading theme',
    );

    final node = tester.getSemantics(
      find.bySemanticsLabel('Open theme choices'),
    );
    expect(node.label, 'Open theme choices');
    expect(node.flagsCollection.isButton, isTrue);
    expect(node.flagsCollection.isEnabled, Tristate.isTrue);
    expect(node.flagsCollection.isExpanded, Tristate.isTrue);
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    expect(find.bySemanticsLabel('Choose a reading theme'), findsNothing);
    expect(find.bySemanticsLabel('Palette icon'), findsNothing);
    semantics.dispose();
  });

  testWidgets('a disabled control reports its state without a tap action', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpPressable(tester, onPress: null, expanded: false);

    final node = tester.getSemantics(
      find.bySemanticsLabel('Open theme choices'),
    );
    expect(node.flagsCollection.isButton, isTrue);
    expect(node.flagsCollection.isEnabled, Tristate.isFalse);
    expect(node.flagsCollection.isExpanded, Tristate.isFalse);
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
    semantics.dispose();
  });

  testWidgets('Enter and Space each activate the focused control once', (
    tester,
  ) async {
    var activations = 0;
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    await pumpPressable(
      tester,
      onPress: () => activations++,
      focusNode: focusNode,
    );

    focusNode.requestFocus();
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(activations, 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(activations, 2);
  });

  testWidgets('only keyboard traversal draws the theme focus colour', (
    tester,
  ) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    await pumpPressable(tester, onPress: () {}, focusNode: focusNode);

    Border focusBorder() {
      final container = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byType(Pressable),
          matching: find.byType(AnimatedContainer),
        ),
      );
      return (container.decoration! as BoxDecoration).border! as Border;
    }

    expect(focusBorder().top.color, Colors.transparent);

    focusNode.requestFocus();
    await tester.pumpAndSettle();

    expect(
      focusBorder().top.color,
      Colors.transparent,
      reason: 'programmatic launch focus must not look user-selected',
    );

    focusNode.unfocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(Pressable));
    expect(focusNode.hasFocus, isTrue);
    expect(focusBorder().top.color, Theme.of(context).colorScheme.primary);
  });
}
