import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/api/widgets/model_backed_selection_area.dart';

void main() {
  testWidgets('select all copies text which was never mounted', (tester) async {
    const whole = 'opening\n\nunmounted middle\n\nending';
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
    const mounted = ValueKey('mounted-text');
    await tester.pumpWidget(
      const MaterialApp(
        home: ModelBackedSelectionArea(
          wholeText: _wholeText,
          child: Text('opening', key: mounted),
        ),
      ),
    );

    final context = tester.element(find.byKey(mounted));
    Actions.invoke(
      context,
      const SelectAllTextIntent(SelectionChangedCause.keyboard),
    );
    Actions.invoke(context, CopySelectionTextIntent.copy);
    await tester.pump();

    expect(copied, whole);
  });

  testWidgets('a streamed append does not move the selected document end', (
    tester,
  ) async {
    var whole = 'committed prefix';
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
    const mounted = ValueKey('mounted-text');
    Widget page() => MaterialApp(
      home: ModelBackedSelectionArea(
        wholeText: () => whole,
        child: const Text('committed prefix', key: mounted),
      ),
    );
    await tester.pumpWidget(page());

    final context = tester.element(find.byKey(mounted));
    Actions.invoke(
      context,
      const SelectAllTextIntent(SelectionChangedCause.keyboard),
    );
    whole = 'committed prefix\n\nstreamed tail';
    await tester.pumpWidget(page());
    Actions.invoke(
      tester.element(find.byKey(mounted)),
      CopySelectionTextIntent.copy,
    );
    await tester.pump();

    expect(copied, 'committed prefix');
  });
}

String _wholeText() => 'opening\n\nunmounted middle\n\nending';
