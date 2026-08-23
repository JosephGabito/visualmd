import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import '../../application/ports/folder_scanner.dart';
import '../../application/ports/markdown_scanner.dart';
import '../../domain/library/markdown_file.dart';
import 'browser_folder.dart';
import 'browser_markdown.dart';

/// Adapter: turns folders dragged onto the page into [FolderRef]s.
/// Listens on the document so the whole window is the drop target.
final class BrowserFolderDrop {
  final BrowserFolderRegistry _registry;
  final BrowserMarkdownRegistry _markdownRegistry;
  final _drops = StreamController<FolderRef>.broadcast();
  final _markdownDrops = StreamController<MarkdownRef>.broadcast();
  final _dragging = StreamController<bool>.broadcast();
  var _depth = 0;

  BrowserFolderDrop(this._registry, this._markdownRegistry);

  /// A folder was dropped and is ready to be opened.
  Stream<FolderRef> get drops => _drops.stream;
  Stream<MarkdownRef> get markdownDrops => _markdownDrops.stream;

  /// True while something droppable is being dragged over the window.
  Stream<bool> get dragging => _dragging.stream;

  void listen() {
    web.document.addEventListener(
      'dragenter',
      ((web.DragEvent event) {
        event.preventDefault();
        if (_depth++ == 0) _dragging.add(true);
      }).toJS,
    );
    web.document.addEventListener(
      'dragover',
      ((web.DragEvent event) {
        event.preventDefault();
        event.dataTransfer?.dropEffect = 'copy';
      }).toJS,
    );
    web.document.addEventListener(
      'dragleave',
      ((web.DragEvent event) {
        event.preventDefault();
        if (--_depth <= 0) {
          _depth = 0;
          _dragging.add(false);
        }
      }).toJS,
    );
    web.document.addEventListener(
      'drop',
      ((web.DragEvent event) {
        event.preventDefault();
        _depth = 0;
        _dragging.add(false);
        final transfer = event.dataTransfer;
        if (_acceptModern(transfer)) return;
        final markdown = _markdownFrom(transfer);
        if (markdown != null) {
          _markdownDrops.add(
            _markdownRegistry.register(
              markdown.name,
              BrowserMarkdownFile(markdown),
            ),
          );
          return;
        }
        final folder = _folderFrom(transfer);
        if (folder != null) _drops.add(_registry.register(folder.name, folder));
      }).toJS,
    );
  }

  /// File-system handles must be requested while the trusted drop event is
  /// still on the stack; their promises may resolve after the handler returns.
  bool _acceptModern(web.DataTransfer? transfer) {
    if (transfer == null || transfer.items.length != 1) return false;
    final item = transfer.items[0];
    final object = item as JSObject;
    if (!object.has('getAsFileSystemHandle')) return false;
    final promise = object.callMethod<JSPromise<JSObject?>>(
      'getAsFileSystemHandle'.toJS,
    );
    final fallbackMarkdown = _markdownFrom(transfer);
    final fallbackFolder = _folderFrom(transfer);
    unawaited(_finishModern(promise, fallbackMarkdown, fallbackFolder));
    return true;
  }

  Future<void> _finishModern(
    JSPromise<JSObject?> promise,
    web.File? fallbackMarkdown,
    BrowserFolder? fallbackFolder,
  ) async {
    try {
      final value = await promise.toDart;
      if (value != null) {
        final handle = value as web.FileSystemHandle;
        if (handle.kind == 'directory') {
          final folder = HandleDirectory(
            value as web.FileSystemDirectoryHandle,
          );
          _drops.add(_registry.register(folder.name, folder));
          return;
        }
        if (MarkdownFile.isMarkdown(handle.name)) {
          _markdownDrops.add(
            _markdownRegistry.register(
              handle.name,
              BrowserMarkdownHandle(value as web.FileSystemFileHandle),
            ),
          );
          return;
        }
      }
    } on Object {
      // The legacy entry captured during the trusted event remains usable.
    }
    if (fallbackMarkdown != null) {
      _markdownDrops.add(
        _markdownRegistry.register(
          fallbackMarkdown.name,
          BrowserMarkdownFile(fallbackMarkdown),
        ),
      );
    } else if (fallbackFolder != null) {
      _drops.add(_registry.register(fallbackFolder.name, fallbackFolder));
    }
  }

  web.File? _markdownFrom(web.DataTransfer? transfer) {
    if (transfer == null || transfer.items.length != 1) return null;
    final item = transfer.items[0];
    if (item.kind != 'file') return null;
    final entry = item.webkitGetAsEntry();
    if (entry?.isDirectory ?? false) return null;
    final file = item.getAsFile();
    return file != null && MarkdownFile.isMarkdown(file.name) ? file : null;
  }

  /// Entries must be taken synchronously inside the drop handler.
  /// One dropped directory becomes the library; loose markdown files dropped
  /// together become a small library of their own.
  BrowserFolder? _folderFrom(web.DataTransfer? transfer) {
    if (transfer == null) return null;
    final items = transfer.items;
    final loose = <(String, web.File)>[];
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      if (item.kind != 'file') continue;
      final entry = item.webkitGetAsEntry();
      if (entry != null && entry.isDirectory) {
        return DroppedDirectory(entry as web.FileSystemDirectoryEntry);
      }
      final file = item.getAsFile();
      if (file != null) loose.add((file.name, file));
    }
    if (loose.isEmpty) return null;
    final name = loose.length == 1 ? loose.single.$1 : 'Dropped files';
    return PickedFiles(name: name, files: loose);
  }
}
