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
      'Show or Hide Shelf',
      'Show or Hide Outline',
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
}
