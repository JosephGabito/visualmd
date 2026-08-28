// ignore_for_file: prefer_initializing_formals — public injection stays named.

import 'dart:async';

import 'package:flutter/services.dart';

import '../../application/ports/external_open_item.dart';
import '../../application/ports/reader_source_picker.dart';
import '../../domain/library/markdown_file.dart';
import 'desktop_workspace_files.dart';
import 'local_folder.dart';
import 'local_markdown.dart';

/// Turns Finder double-click and Open With requests into opaque reader refs.
///
/// The native runner queues cold-launch requests until Dart announces that
/// this channel is ready. A single-subscription controller then preserves
/// request order while the composition root performs each open operation.
final class DesktopExternalOpenItems {
  static const methodChannel = MethodChannel(
    'com.visualmd.visualmd/external-open-items',
  );

  final LocalMarkdownRegistry _markdowns;
  final DesktopWorkspaceFiles _workspaces;
  final MethodChannel _channel;
  final StreamController<ExternalOpenItem> _items =
      StreamController<ExternalOpenItem>();

  DesktopExternalOpenItems(
    this._markdowns,
    this._workspaces, {
    MethodChannel channel = methodChannel,
    bool announceReady = true,
  }) : _channel = channel {
    _channel.setMethodCallHandler(_handleMethodCall);
    if (announceReady) {
      scheduleMicrotask(() => _channel.invokeMethod<void>('ready'));
    }
  }

  Stream<ExternalOpenItem> get stream => _items.stream;

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method != 'open') throw MissingPluginException();
    accept(call.arguments);
  }

  /// Accepts the platform record shape after the method-channel boundary.
  /// Public so the classification and authority handoff can be tested without
  /// manufacturing a reverse platform message.
  void accept(Object? raw) {
    if (raw is! List<Object?>) return;
    for (final entry in raw) {
      if (entry is! Map<Object?, Object?>) continue;
      final path = entry['path'];
      if (path is! String || path.isEmpty) continue;
      final bookmark = entry['bookmark'] is Uint8List
          ? entry['bookmark']! as Uint8List
          : null;
      final name = baseName(path);

      if (name.toLowerCase().endsWith('.visualmd-workspace.json')) {
        _items.add(
          ExternalWorkspace(_workspaces.registerOpened(path, bookmark)),
        );
      } else if (MarkdownFile.isMarkdown(name)) {
        final markdown = LocalMarkdown(path, bookmark: bookmark);
        _items.add(
          ExternalReaderSource(
            MarkdownSourceSelection(
              _markdowns.register(
                name,
                markdown,
                identity: localMarkdownIdentity(path),
              ),
            ),
          ),
        );
      }
    }
  }

  void dispose() {
    _channel.setMethodCallHandler(null);
    _items.close();
  }
}
