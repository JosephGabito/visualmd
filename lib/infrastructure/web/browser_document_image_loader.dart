import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import '../../application/ports/document_image_loader.dart';
import '../../application/ports/folder_scanner.dart';
import '../../domain/library/document_id.dart';
import 'browser_folder.dart';

/// Reads relative images through the same browser folder capability that
/// supplied the Markdown.
///
/// A standalone browser file has no parent-directory capability, so only a
/// folder drop or folder picker can resolve its neighbours. Remote images are
/// intentionally left to Flutter's network image path.
final class BrowserDocumentImageLoader implements DocumentImageLoader {
  final BrowserFolderRegistry _folders;

  const BrowserDocumentImageLoader(this._folders);

  @override
  Future<Uint8List?> load(DocumentId document, String source) async {
    final relative = DocumentImagePath.resolve(
      documentPath: document.path,
      source: source,
    );
    if (relative == null) return null;
    final folder = _folders.lookup(
      FolderRef(id: document.rootId.value, name: ''),
    );
    if (folder == null) return null;

    try {
      return await switch (folder) {
        HandleDirectory(:final handle) => _fromHandle(handle, relative),
        DroppedDirectory(:final entry) => _fromEntry(entry, relative),
        PickedFiles(:final files) => _fromPicked(files, relative),
      };
    } on Object {
      return null;
    }
  }

  static Future<Uint8List?> _fromHandle(
    web.FileSystemDirectoryHandle root,
    String path,
  ) async {
    final segments = path.split('/');
    var directory = root;
    for (final segment in segments.take(segments.length - 1)) {
      directory = await directory.getDirectoryHandle(segment).toDart;
    }
    final handle = await directory.getFileHandle(segments.last).toDart;
    return _bytes(await handle.getFile().toDart);
  }

  static Future<Uint8List?> _fromEntry(
    web.FileSystemDirectoryEntry root,
    String path,
  ) async {
    web.FileSystemEntry current = root;
    for (final segment in path.split('/')) {
      if (!current.isDirectory) return null;
      final entries = await _entriesOf(current as web.FileSystemDirectoryEntry);
      final matching = entries.where((entry) => entry.name == segment);
      if (matching.isEmpty) return null;
      current = matching.first;
    }
    if (!current.isFile) return null;
    return _bytes(await _fileOf(current as web.FileSystemFileEntry));
  }

  static Future<Uint8List?> _fromPicked(
    List<(String, web.File)> files,
    String path,
  ) async {
    for (final (candidate, file) in files) {
      if (candidate.replaceAll('\\', '/') == path) return _bytes(file);
    }
    return null;
  }

  static Future<Uint8List> _bytes(web.File file) async {
    final buffer = await file.arrayBuffer().toDart;
    return buffer.toDart.asUint8List();
  }

  /// `readEntries` is batched and completes only after an empty batch.
  static Future<List<web.FileSystemEntry>> _entriesOf(
    web.FileSystemDirectoryEntry directory,
  ) async {
    final reader = directory.createReader();
    final all = <web.FileSystemEntry>[];
    while (true) {
      final completer = Completer<List<web.FileSystemEntry>>();
      reader.readEntries(
        ((JSArray<web.FileSystemEntry> entries) => completer.complete(
          entries.toDart,
        )).toJS,
        ((web.DOMException error) => completer.completeError(error)).toJS,
      );
      final batch = await completer.future;
      if (batch.isEmpty) return all;
      all.addAll(batch);
    }
  }

  static Future<web.File> _fileOf(web.FileSystemFileEntry entry) {
    final completer = Completer<web.File>();
    entry.file(
      ((web.File file) => completer.complete(file)).toJS,
      ((web.DOMException error) => completer.completeError(error)).toJS,
    );
    return completer.future;
  }
}
