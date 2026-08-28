import 'dart:async';

import 'package:flutter/services.dart';

import '../platform/platform_command.dart';
import '../platform/native_reader_state.dart';

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
        'openAppearance' => PlatformCommand.openAppearance,
        'findDocument' => PlatformCommand.findDocument,
        'searchLibrary' => PlatformCommand.searchLibrary,
        'toggleShelf' => PlatformCommand.toggleShelf,
        'toggleOutline' => PlatformCommand.toggleOutline,
        'enlargeText' => PlatformCommand.enlargeText,
        'shrinkText' => PlatformCommand.shrinkText,
        'resetText' => PlatformCommand.resetText,
        'showKeyboardShortcuts' => PlatformCommand.showKeyboardShortcuts,
        'openSupport' => PlatformCommand.openSupport,
        'openPrivacy' => PlatformCommand.openPrivacy,
        'showLicenses' => PlatformCommand.showLicenses,
        _ => null,
      };
      if (command != null) _controller.add(command);
    });
  }

  Stream<PlatformCommand> get stream => _controller.stream;

  /// Sends state in the opposite direction over the command channel so AppKit
  /// can validate its own menu items and name its otherwise hidden window.
  Future<void> syncReaderState(NativeReaderState state) async {
    try {
      await _channel.invokeMethod<void>('updateReaderState', {
        'documentTitle': state.documentTitle,
        'hasLibrary': state.hasLibrary,
        'hasDocument': state.hasDocument,
        'shelfVisible': state.shelfVisible,
        'outlineVisible': state.outlineVisible,
      });
    } on MissingPluginException {
      // A desktop embedder without this optional host projection keeps its
      // ordinary system title and menu validation.
    }
  }
}
