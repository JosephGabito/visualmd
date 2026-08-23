import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/widgets.dart';

import '../../application/ports/folder_scanner.dart';
import '../../application/ports/markdown_scanner.dart';
import '../../domain/library/markdown_file.dart';
import 'local_folder.dart';
import 'local_markdown.dart';

/// Adapter: folders dragged onto the desktop window become [FolderRef]s.
/// Desktop drop arrives through a widget, so this adapter hands back a
/// wrapper the UI places around its content without knowing the plugin.
final class DesktopFolderDrop {
  final LocalFolderRegistry _registry;
  final LocalMarkdownRegistry _markdownRegistry;
  final _drops = StreamController<FolderRef>.broadcast();
  final _markdownDrops = StreamController<MarkdownRef>.broadcast();
  final _dragging = StreamController<bool>.broadcast();

  DesktopFolderDrop(this._registry, this._markdownRegistry);

  Stream<FolderRef> get drops => _drops.stream;
  Stream<MarkdownRef> get markdownDrops => _markdownDrops.stream;
  Stream<bool> get dragging => _dragging.stream;

  Widget wrap(Widget child) => DropTarget(
    onDragEntered: (_) => _dragging.add(true),
    onDragExited: (_) => _dragging.add(false),
    onDragDone: (details) {
      _dragging.add(false);
      final markdown = _markdownFrom(details.files);
      if (markdown != null) {
        final identity = localMarkdownIdentity(markdown.path);
        _markdownDrops.add(
          _markdownRegistry.register(
            baseName(markdown.path),
            markdown,
            identity: identity,
          ),
        );
        return;
      }
      final folder = _folderFrom(details.files);
      if (folder != null) {
        final identity = folder is LocalDirectory
            ? localFolderIdentity(folder.path)
            : null;
        _drops.add(_registry.register(folder.name, folder, identity: identity));
      }
    },
    child: child,
  );

  LocalMarkdown? _markdownFrom(List<DropItem> items) {
    if (items.length != 1) return null;
    final item = items.single;
    if (item is DropItemDirectory ||
        FileSystemEntity.isDirectorySync(item.path) ||
        !MarkdownFile.isMarkdown(item.path)) {
      return null;
    }
    return LocalMarkdown(item.path, bookmark: item.extraAppleBookmark);
  }

  /// One dropped directory becomes the library; loose files dropped together
  /// become a small library of their own.
  LocalFolder? _folderFrom(List<DropItem> items) {
    final loose = <(String, Uint8List?)>[];
    for (final item in items) {
      if (item is DropItemDirectory ||
          FileSystemEntity.isDirectorySync(item.path)) {
        return LocalDirectory(item.path, bookmark: item.extraAppleBookmark);
      }
      loose.add((item.path, item.extraAppleBookmark));
    }
    if (loose.isEmpty) return null;
    return LocalFiles(
      name: loose.length == 1 ? baseName(loose.single.$1) : 'Dropped files',
      files: loose,
    );
  }
}
