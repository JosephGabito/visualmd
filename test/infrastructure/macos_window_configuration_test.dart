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

  test('macOS restores the last frame after enforcing the usable minimum', () {
    final source = File('macos/Runner/MainFlutterWindow.swift')
        .readAsStringSync();

    const minimum = 'self.minSize = NSSize(width: 720, height: 480)';
    const autosave = '_ = self.setFrameAutosaveName("visualmd.main-window")';
    expect(source, contains(minimum));
    expect(source, contains(autosave));
    expect(source.indexOf(minimum), lessThan(source.indexOf(autosave)));
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

  test('closing the last macOS window does not quit the app', () {
    final source = File('macos/Runner/AppDelegate.swift').readAsStringSync();

    expect(
      source,
      contains(
        'applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication)',
      ),
    );
    expect(source, contains('false'));
  });

  test('clicking the Dock icon reopens the reader window', () {
    final source = File('macos/Runner/AppDelegate.swift').readAsStringSync();

    expect(source, contains('applicationShouldHandleReopen'));
    expect(source, contains('mainFlutterWindow?.makeKeyAndOrderFront(self)'));
  });
}
