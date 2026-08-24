import 'dart:async';

import 'package:flutter/services.dart';

import '../platform/platform_command.dart';

/// Receives selections from the host application's native menu bar.
final class DesktopCommands {
  static const _channel = MethodChannel('com.visualmd.visualmd/commands');

  final _controller = StreamController<PlatformCommand>.broadcast();

  DesktopCommands() {
    _channel.setMethodCallHandler((call) async {
      final command = switch (call.method) {
        'newWorkspace' => PlatformCommand.newWorkspace,
        'openWorkspace' => PlatformCommand.openWorkspace,
        'openReaderSources' => PlatformCommand.openReaderSources,
        'openSampleLibrary' => PlatformCommand.openSampleLibrary,
        'saveWorkspace' => PlatformCommand.saveWorkspace,
        'saveWorkspaceAs' => PlatformCommand.saveWorkspaceAs,
        'addFolder' => PlatformCommand.addFolder,
        'addMarkdown' => PlatformCommand.addMarkdown,
        _ => null,
      };
      if (command != null) _controller.add(command);
    });
  }

  Stream<PlatformCommand> get stream => _controller.stream;
}
