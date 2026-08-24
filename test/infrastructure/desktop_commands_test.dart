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
}
