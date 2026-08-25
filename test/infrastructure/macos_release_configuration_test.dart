import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String source(String path) => File(path).readAsStringSync();

  group('the macOS release contract', () {
    test('release code is hardened without debugger entitlement injection', () {
      final configuration = source('macos/Runner/Configs/Release.xcconfig');

      expect(configuration, contains('ENABLE_HARDENED_RUNTIME = YES'));
      expect(
        configuration,
        contains('CODE_SIGN_INJECT_BASE_ENTITLEMENTS = NO'),
      );
    });

    test('the shipping sandbox grants only reader capabilities', () {
      final entitlements = source('macos/Runner/Release.entitlements');

      for (final capability in [
        'com.apple.security.app-sandbox',
        'com.apple.security.files.bookmarks.app-scope',
        'com.apple.security.files.user-selected.read-write',
        'com.apple.security.network.client',
      ]) {
        expect(entitlements, contains('<key>$capability</key>'));
      }
      for (final debugCapability in [
        'com.apple.security.cs.allow-jit',
        'com.apple.security.get-task-allow',
        'com.apple.security.network.server',
      ]) {
        expect(entitlements, isNot(contains(debugCapability)));
      }
    });

    test('the app declares privacy without inventing data collection', () {
      final privacy = source('macos/Runner/PrivacyInfo.xcprivacy');
      final project = source('macos/Runner.xcodeproj/project.pbxproj');

      expect(privacy, contains('NSPrivacyAccessedAPICategoryFileTimestamp'));
      expect(privacy, contains('<string>3B52.1</string>'));
      expect(privacy, contains('<string>C617.1</string>'));
      expect(privacy, contains('<key>NSPrivacyTracking</key>\n\t<false/>'));
      expect(
        privacy,
        contains('<key>NSPrivacyCollectedDataTypes</key>\n\t<array/>'),
      );
      expect(project, contains('PrivacyInfo.xcprivacy in Resources'));
    });

    test('bundle metadata answers App Store submission questions once', () {
      final information = source('macos/Runner/Info.plist');

      expect(
        information,
        contains('<string>public.app-category.productivity</string>'),
      );
      expect(
        information,
        contains('<key>ITSAppUsesNonExemptEncryption</key>\n\t<false/>'),
      );
    });
  });
}
