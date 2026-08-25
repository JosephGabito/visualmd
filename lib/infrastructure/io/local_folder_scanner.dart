// ignore_for_file: prefer_initializing_formals — private fields stay private; named params stay public.
import 'dart:convert';
import 'dart:io';

import '../../application/ports/folder_document_scanner.dart';
import '../../application/ports/folder_scanner.dart';
import '../../domain/library/hidden_folders.dart';
import '../../domain/library/library_builder.dart';
import '../../domain/library/markdown_file.dart';
import '../../domain/reading/document_outline.dart';
import 'local_folder.dart';
import 'local_markdown.dart';
import 'scoped_access.dart';

/// Adapter: reads markdown files out of folders on the local filesystem.
/// Like the browser scanner, it only reads what the domain would keep.
final class LocalFolderScanner implements FolderScanner, FolderDocumentScanner {
  final LocalFolderRegistry _registry;
  final ScopedAccess _access;

  const LocalFolderScanner(
    this._registry, {
    ScopedAccess access = const OpenAccess(),
  }) : _access = access;

  @override
  Future<ScannedFolder> scan(FolderRef ref) async {
    final folder = _registry.lookup(ref);
    if (folder == null) throw FolderUnavailable(ref);

    try {
      final files = <FileEntry>[];
      switch (folder) {
        case LocalDirectory(:final path, :final bookmark):
          await _access.within(
            bookmark,
            () => _walk(Directory(path), '', files),
          );
        case LocalFiles(files: final loose):
          for (final (path, bookmark) in loose) {
            final name = baseName(path);
            if (!MarkdownFile.isMarkdown(name)) continue;
            files.add(
              await _access.within(bookmark, () => _entry(name, File(path))),
            );
          }
      }
      return ScannedFolder(name: folder.name, files: files);
    } on FileSystemException {
      throw FolderUnavailable(ref);
    }
  }

  static Future<FileEntry> _entry(String path, File file) async {
    final source = await _read(file);
    return FileEntry(
      path,
      null,
      sourceId: localDocumentSourceId(file.path),
      title: DocumentOutline.titleOf(source),
    );
  }

  @override
  Future<ScannedFolderDocument?> scanDocument(
    FolderRef ref,
    String relativePath,
  ) async {
    final folder = _registry.lookup(ref);
    if (folder == null) throw FolderUnavailable(ref);
    final normalized = _safeRelativePath(relativePath);
    if (normalized == null ||
        !MarkdownFile.isMarkdown(normalized) ||
        HiddenFolders.hidesPath(normalized)) {
      return null;
    }

    switch (folder) {
      case LocalDirectory(:final path, :final bookmark):
        final root = Directory(path);
        if (!await root.exists()) throw FolderUnavailable(ref);
        final file = File(
          [path, ...normalized.split('/')].join(Platform.pathSeparator),
        );
        try {
          return await _access.within(bookmark, () async {
            if (!await file.exists()) return null;
            return ScannedFolderDocument(
              relativePath: normalized,
              content: await _read(file),
              sourceId: localDocumentSourceId(file.path),
            );
          });
        } on FileSystemException {
          if (!await root.exists()) throw FolderUnavailable(ref);
          if (!await file.exists()) return null;
          rethrow;
        }
      case LocalFiles(files: final files):
        for (final (path, bookmark) in files) {
          if (baseName(path) != normalized) continue;
          final file = File(path);
          try {
            return await _access.within(bookmark, () async {
              if (!await file.exists()) return null;
              return ScannedFolderDocument(
                relativePath: normalized,
                content: await _read(file),
                sourceId: localDocumentSourceId(path),
              );
            });
          } on FileSystemException {
            if (!await file.exists()) return null;
            rethrow;
          }
        }
        return null;
    }
  }

  Future<void> _walk(
    Directory directory,
    String prefix,
    List<FileEntry> out,
  ) async {
    final entries = await directory.list(followLinks: false).toList();
    for (final entry in entries) {
      final name = baseName(entry.path);
      final path = '$prefix$name';
      if (entry is Directory) {
        if (HiddenFolders.isHidden(name)) continue;
        await _walk(entry, '$path/', out);
      } else if (entry is File && MarkdownFile.isMarkdown(name)) {
        out.add(await _entry(path, entry));
      }
    }
  }

  /// Markdown is text; a stray invalid byte should not sink the whole library.
  static Future<String> _read(File file) async =>
      utf8.decode(await file.readAsBytes(), allowMalformed: true);
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
