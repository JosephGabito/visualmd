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
}
