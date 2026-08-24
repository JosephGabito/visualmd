import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('macOS launches in the full desktop composition', () {
    final source = File('macos/Runner/Base.lproj/MainMenu.xib')
        .readAsStringSync();

    expect(
      source,
      contains(
        '<rect key="contentRect" x="335" y="390" width="1280" height="800"/>',
      ),
    );
  });

  test('macOS removes native menus that have no reader actions', () {
    final source = File('macos/Runner/MainFlutterWindow.swift')
        .readAsStringSync();

    expect(source, contains('["Edit", "Help"]'));
    expect(source, contains('mainMenu.removeItem(unusedMenu)'));
  });

  test('macOS does not carry the traffic-light toolbar into fullscreen', () {
    final source = File('macos/Runner/MainFlutterWindow.swift')
        .readAsStringSync();

    expect(source, contains('NSWindow.willEnterFullScreenNotification'));
    expect(source, contains('NSWindow.willExitFullScreenNotification'));
    expect(source, contains('toolbar?.isVisible = false'));
    expect(source, contains('toolbar?.isVisible = true'));
  });
}
