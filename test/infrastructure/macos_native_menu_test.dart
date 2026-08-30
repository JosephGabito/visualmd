import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String source(String path) => File(path).readAsStringSync();

  test('the native menu exposes reader commands without editor furniture', () {
    final runner = source('macos/Runner/MainFlutterWindow.swift');
    final xib = source('macos/Runner/Base.lproj/MainMenu.xib');

    for (final title in [
      'Close Window',
      'Find in Document…',
      'Search Library…',
      'Shelf',
      'Outline',
      'Increase Text Size',
      'Decrease Text Size',
      'Actual Size',
      'Keyboard Shortcuts',
      'Support',
      'Privacy',
      'Open-Source Licenses',
    ]) {
      expect(runner, contains('"$title"'));
    }

    expect(runner, isNot(contains('removeItem(unusedMenu)')));
    expect(xib, contains('title="Settings…" keyEquivalent=","'));
    for (final editorOnly in [
      'Undo',
      'Redo',
      'Paste and Match Style',
      'Spelling and Grammar',
      'Substitutions',
      'Transformations',
    ]) {
      expect(xib, isNot(contains('title="$editorOnly"')));
    }
  });

  test('native reader items validate and check against Flutter state', () {
    final runner = source('macos/Runner/MainFlutterWindow.swift');

    expect(runner, contains('NSObject, NSMenuItemValidation'));
    expect(runner, contains('return state.hasLibrary'));
    expect(runner, contains('return state.hasDocument'));
    expect(runner, contains('return state.hasOutline'));
    expect(runner, contains('return state.canCopy'));
    expect(runner, contains('return state.canIncreaseText'));
    expect(runner, contains('return state.canDecreaseText'));
    expect(runner, contains('return state.canResetText'));
    expect(
      runner,
      contains('shelfItem?.state = state.shelfVisible ? .on : .off'),
    );
    expect(
      runner,
      contains(
        'outlineItem?.state = state.outlineVisible && state.hasOutline ? .on : .off',
      ),
    );
    expect(runner, contains('self.nativeMenuController?.update(state)'));
  });

  test('native selection commands cross the Flutter method channel', () {
    final runner = source('macos/Runner/MainFlutterWindow.swift');

    expect(runner, contains('@objc func copySelection()'));
    expect(runner, contains('@objc func selectAllText()'));
    expect(runner, isNot(contains('#selector(NSText.copy(_:))')));
    expect(runner, isNot(contains('#selector(NSText.selectAll(_:))')));
  });

  test(
    'the hidden native title follows the document with a product fallback',
    () {
      final runner = source('macos/Runner/MainFlutterWindow.swift');
      final composition = source('lib/main.dart');

      expect(runner, contains('call.method == "updateReaderState"'));
      expect(runner, contains('self.title ='));
      expect(runner, contains('self.title = "Visual MD"'));
      expect(
        composition,
        contains('controller.addListener(syncNativeReaderState)'),
      );
      expect(
        composition,
        contains('documentTitle: controller.reading?.document.title'),
      );
      expect(
        composition,
        contains('WidgetsBinding.instance.addPostFrameCallback'),
      );
    },
  );
}
