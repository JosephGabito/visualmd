import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String source(String path) => File(path).readAsStringSync();

  test('the bundle accepts Markdown and JSON as alternate document types', () {
    final plist = source('macos/Runner/Info.plist');

    expect(plist, contains('<string>net.daringfireball.markdown</string>'));
    expect(plist, contains('<string>public.json</string>'));
    expect(
      RegExp(r'<string>Alternate</string>').allMatches(plist),
      hasLength(2),
    );
    expect(plist, isNot(contains('<key>CFBundleTypeExtensions</key>')));
  });

  test('cold and warm Finder requests share one readiness-gated channel', () {
    final delegate = source('macos/Runner/AppDelegate.swift');
    final window = source('macos/Runner/MainFlutterWindow.swift');

    expect(delegate, contains('openFiles filenames: [String]'));
    expect(delegate, contains('pendingOpenFiles.append'));
    expect(delegate, contains('takePendingOpenFiles()'));
    expect(delegate, contains('makeKeyAndOrderFront'));
    expect(window, contains('com.visualmd.visualmd/external-open-items'));
    expect(window, contains('call.method == "ready"'));
    expect(window, contains('bookmarkData('));
    expect(window, contains('FlutterStandardTypedData(bytes: bookmark)'));
  });
}
