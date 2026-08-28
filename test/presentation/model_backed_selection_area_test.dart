import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/api/widgets/model_backed_selection_area.dart';
import 'package:visualmd/presentation/theme/typographic_punctuation.dart';

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
          selectionIdentity: 'document',
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
        selectionIdentity: 'document',
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

  test('lazy block ranges assemble in document order', () {
    final snapshot = ModelSelectionSnapshot();
    snapshot.update(
      identity: 'middle',
      order: 1,
      text: 'middle block',
      range: const SelectedContentRange(startOffset: 0, endOffset: 12),
      status: SelectionStatus.uncollapsed,
    );
    snapshot.update(
      identity: 'opening',
      order: 0,
      text: 'opening block',
      range: const SelectedContentRange(startOffset: 3, endOffset: 13),
      status: SelectionStatus.uncollapsed,
    );
    snapshot.update(
      identity: 'ending',
      order: 2,
      text: 'ending block',
      range: const SelectedContentRange(startOffset: 6, endOffset: 0),
      status: SelectionStatus.uncollapsed,
    );

    expect(snapshot.selectedText, 'ning block\n\nmiddle block\n\nending');

    snapshot.update(
      identity: 'middle',
      order: 1,
      text: 'middle block',
      range: null,
      status: SelectionStatus.none,
    );
    expect(snapshot.selectedText, 'ning block\n\nending');
  });

  test(
    'a virtual text window records ranges in complete-block coordinates',
    () {
      final snapshot = ModelSelectionSnapshot();

      snapshot.update(
        identity: 'paragraph',
        order: 0,
        text: 'opening middle ending',
        rangeOffset: 8,
        range: const SelectedContentRange(startOffset: 0, endOffset: 6),
        status: SelectionStatus.uncollapsed,
      );

      expect(snapshot.selectedText, 'middle');
    },
  );

  test('a display contraction copies its exact authored source range', () {
    final snapshot = ModelSelectionSnapshot();
    final projection = TypographicProjection.of('a--b...c');

    snapshot.update(
      identity: 'paragraph',
      order: 0,
      text: projection.source,
      sourceOffsetAt: projection.sourceOffsetAt,
      range: const SelectedContentRange(startOffset: 1, endOffset: 4),
      status: SelectionStatus.uncollapsed,
    );

    expect(snapshot.selectedText, '--b...');
  });
}

String _wholeText() => 'opening\n\nunmounted middle\n\nending';
