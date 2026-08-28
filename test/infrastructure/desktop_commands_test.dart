import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/infrastructure/io/desktop_commands.dart';
import 'package:visualmd/infrastructure/platform/platform_command.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'a native File menu selection reaches the typed command stream',
    () async {
      final commands = DesktopCommands();
      final received = commands.stream.first;

      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            'com.visualmd.visualmd/commands',
            const StandardMethodCodec().encodeMethodCall(
              const MethodCall('saveWorkspaceAs'),
            ),
            (_) {},
          );

      expect(await received, PlatformCommand.saveWorkspaceAs);
    },
  );

  test(
    'the native Open item requests reader sources, not a workspace',
    () async {
      final commands = DesktopCommands();
      final received = commands.stream.first;

      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            'com.visualmd.visualmd/commands',
            const StandardMethodCodec().encodeMethodCall(
              const MethodCall('openReaderSources'),
            ),
            (_) {},
          );

      expect(await received, PlatformCommand.openReaderSources);
    },
  );

  test('the native sample item reaches its distinct command', () async {
    final commands = DesktopCommands();
    final received = commands.stream.first;

    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          'com.visualmd.visualmd/commands',
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('openSampleLibrary'),
          ),
          (_) {},
        );

    expect(await received, PlatformCommand.openSampleLibrary);
  });

  for (final entry in {
    'openAppearance': PlatformCommand.openAppearance,
    'findDocument': PlatformCommand.findDocument,
    'searchLibrary': PlatformCommand.searchLibrary,
    'toggleShelf': PlatformCommand.toggleShelf,
    'toggleOutline': PlatformCommand.toggleOutline,
    'enlargeText': PlatformCommand.enlargeText,
    'shrinkText': PlatformCommand.shrinkText,
    'resetText': PlatformCommand.resetText,
    'showKeyboardShortcuts': PlatformCommand.showKeyboardShortcuts,
    'openSupport': PlatformCommand.openSupport,
    'openPrivacy': PlatformCommand.openPrivacy,
    'showLicenses': PlatformCommand.showLicenses,
  }.entries) {
    test('the native ${entry.key} item reaches its typed command', () async {
      final commands = DesktopCommands();
      final received = commands.stream.first;

      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            'com.visualmd.visualmd/commands',
            const StandardMethodCodec().encodeMethodCall(MethodCall(entry.key)),
            (_) {},
          );

      expect(await received, entry.value);
    });
  }
}
