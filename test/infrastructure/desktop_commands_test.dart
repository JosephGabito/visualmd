import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/infrastructure/io/desktop_commands.dart';
import 'package:visualmd/infrastructure/platform/platform_command.dart';
import 'package:visualmd/infrastructure/platform/native_reader_state.dart';

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

  test('reader state is projected back to the native host exactly', () async {
    const channel = MethodChannel('com.visualmd.visualmd/commands');
    MethodCall? received;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          received = call;
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    final commands = DesktopCommands();
    await commands.syncReaderState(
      const NativeReaderState(
        documentTitle: 'Notes',
        hasLibrary: true,
        hasDocument: true,
        shelfVisible: false,
        outlineVisible: true,
      ),
    );

    expect(received?.method, 'updateReaderState');
    expect(received?.arguments, {
      'documentTitle': 'Notes',
      'hasLibrary': true,
      'hasDocument': true,
      'shelfVisible': false,
      'outlineVisible': true,
    });
  });

  test(
    'the active Flutter chrome reaches the native Windows caption',
    () async {
      const channel = MethodChannel('com.visualmd.visualmd/commands');
      MethodCall? received;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            received = call;
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );

      final commands = DesktopCommands();
      await commands.syncWindowChrome(0xff141414, 0xffffffff);

      expect(received?.method, 'updateWindowChrome');
      expect(received?.arguments, {
        'background': 0xff141414,
        'foreground': 0xffffffff,
      });
    },
  );

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
