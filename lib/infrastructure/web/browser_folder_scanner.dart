import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import '../../application/ports/folder_document_scanner.dart';
import '../../application/ports/folder_scanner.dart';
import '../../domain/library/hidden_folders.dart';
import '../../domain/library/library_builder.dart';
import '../../domain/library/markdown_file.dart';
import 'browser_folder.dart';
import 'browser_source_identity.dart';

/// Adapter: reads markdown files out of folders the browser gave us.
/// Only markdown outside hidden folders is read — the domain would discard
/// anything else, so there is no point pulling those bytes off disk.
final class BrowserFolderScanner
    implements FolderScanner, FolderDocumentScanner {
  final BrowserFolderRegistry _registry;
  final BrowserSourceIdentity _identities;

  const BrowserFolderScanner(this._registry, this._identities);

  @override
  Future<ScannedFolder> scan(FolderRef ref) async {
    final folder = _registry.lookup(ref);
    if (folder == null) throw FolderUnavailable(ref);

    final files = <FileEntry>[];
    switch (folder) {
      case HandleDirectory(:final handle):
        await _walkHandle(handle, '', files);
      case DroppedDirectory(:final entry):
        await _walk(entry, '', files);
      case PickedFiles(files: final picked):
        for (final (path, file) in picked) {
          if (!_wanted(path)) continue;
          files.add(FileEntry(path, await _text(file)));
        }
    }
    return ScannedFolder(name: folder.name, files: files);
  }

  @override
  Future<ScannedFolderDocument?> scanDocument(
    FolderRef ref,
    String relativePath,
  ) async {
    final folder = _registry.lookup(ref);
    if (folder == null) throw FolderUnavailable(ref);
    final path = _safeRelativePath(relativePath);
    if (path == null ||
        !MarkdownFile.isMarkdown(path) ||
        HiddenFolders.hidesPath(path)) {
      return null;
    }
    if (folder case HandleDirectory(:var handle)) {
      final segments = path.split('/');
      for (final segment in segments.take(segments.length - 1)) {
        handle = await handle.getDirectoryHandle(segment).toDart;
      }
      final fileHandle = await handle.getFileHandle(segments.last).toDart;
      final file = await fileHandle.getFile().toDart;
      return ScannedFolderDocument(
        relativePath: path,
        content: await _text(file),
        sourceId: await _identities.identify(fileHandle),
      );
    }
    // Legacy drag and input objects are snapshots. Their monitor never emits
    // targeted invalidations because the browser cannot promise a fresh read.
    return null;
  }

  Future<void> _walkHandle(
    web.FileSystemDirectoryHandle directory,
    String prefix,
    List<FileEntry> out,
  ) async {
    final iterator = (directory as JSObject).callMethod<JSObject>(
      'values'.toJS,
    );
    while (true) {
      final result = await iterator
          .callMethod<JSPromise<JSObject>>('next'.toJS)
          .toDart;
      if (result.getProperty<JSBoolean>('done'.toJS).toDart) return;
      final handle = result.getProperty<JSObject>('value'.toJS);
      final entry = handle as web.FileSystemHandle;
      final path = '$prefix${entry.name}';
      if (entry.kind == 'directory') {
        if (HiddenFolders.isHidden(entry.name)) continue;
        await _walkHandle(
          handle as web.FileSystemDirectoryHandle,
          '$path/',
          out,
        );
      } else if (MarkdownFile.isMarkdown(entry.name)) {
        final fileHandle = handle as web.FileSystemFileHandle;
        final file = await fileHandle.getFile().toDart;
        out.add(
          FileEntry(
            path,
            await _text(file),
            sourceId: await _identities.identify(fileHandle),
          ),
        );
      }
    }
  }

  static bool _wanted(String path) =>
      MarkdownFile.isMarkdown(path) && !HiddenFolders.hidesPath(path);

  Future<void> _walk(
    web.FileSystemDirectoryEntry directory,
    String prefix,
    List<FileEntry> out,
  ) async {
    for (final entry in await _entriesOf(directory)) {
      final path = '$prefix${entry.name}';
      if (entry.isDirectory) {
        if (HiddenFolders.isHidden(entry.name)) continue;
        await _walk(entry as web.FileSystemDirectoryEntry, '$path/', out);
      } else if (entry.isFile && MarkdownFile.isMarkdown(entry.name)) {
        final file = await _fileOf(entry as web.FileSystemFileEntry);
        out.add(FileEntry(path, await _text(file)));
      }
    }
  }

  /// `readEntries` returns batches (Chrome: 100 at a time) until an empty one.
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
        ((web.DOMException error) => completer.completeError(
          error.message,
        )).toJS,
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
      ((web.DOMException error) => completer.completeError(error.message)).toJS,
    );
    return completer.future;
  }

  static Future<String> _text(web.File file) async =>
      (await file.text().toDart).toDart;
}

String? _safeRelativePath(String raw) {
  final portable = raw.replaceAll('\\', '/');
  if (portable.isEmpty || portable.startsWith('/')) return null;
  final segments = portable.split('/');
  if (segments.any(
    (segment) => segment.isEmpty || segment == '.' || segment == '..',
  )) {
    return null;
  }
  return segments.join('/');
}
