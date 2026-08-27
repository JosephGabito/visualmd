// ignore_for_file: prefer_initializing_formals — private fields stay private; named params stay public.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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
final class LocalFolderScanner
    implements FolderScanner, FolderMetadataScanner, FolderDocumentScanner {
  static const _maximumConcurrentReads = 8;

  final LocalFolderRegistry _registry;
  final ScopedAccess _access;

  const LocalFolderScanner(
    this._registry, {
    ScopedAccess access = const OpenAccess(),
  }) : _access = access;

  @override
  Future<ScannedFolder> scan(FolderRef ref) async {
    final metadata = await scanMetadata(ref);
    return enrichTitles(ref, metadata);
  }

  @override
  Future<ScannedFolder> scanMetadata(FolderRef ref) async {
    final folder = _registry.lookup(ref);
    if (folder == null) throw FolderUnavailable(ref);

    try {
      final files = <FileEntry>[];
      switch (folder) {
        case LocalDirectory(:final path, :final bookmark):
          files.addAll(
            await _access.within(
              bookmark,
              () => _walkMetadata(Directory(path), ''),
            ),
          );
        case LocalFiles(files: final loose):
          for (final (path, _) in loose) {
            final name = baseName(path);
            if (!MarkdownFile.isMarkdown(name)) continue;
            files.add(
              FileEntry(name, null, sourceId: localDocumentSourceId(path)),
            );
          }
      }
      return ScannedFolder(
        name: folder.name,
        files: files,
        titlesDeferred: true,
      );
    } on FileSystemException {
      throw FolderUnavailable(ref);
    }
  }

  @override
  Future<ScannedFolder> enrichTitles(
    FolderRef ref,
    ScannedFolder metadata,
  ) async {
    if (!metadata.titlesDeferred) return metadata;
    final folder = _registry.lookup(ref);
    if (folder == null) throw FolderUnavailable(ref);
    try {
      final files = switch (folder) {
        LocalDirectory(:final path, :final bookmark) => await _access.within(
          bookmark,
          () => _readBounded([
            for (final entry in metadata.files)
              () => _entry(
                entry.path,
                File(
                  [path, ...entry.path.split('/')].join(Platform.pathSeparator),
                ),
              ),
          ]),
        ),
        LocalFiles(files: final loose) => await _enrichLooseFiles(
          loose,
          metadata.files,
        ),
      };
      return ScannedFolder(name: metadata.name, files: files);
    } on FileSystemException {
      throw FolderUnavailable(ref);
    }
  }

  Future<List<FileEntry>> _enrichLooseFiles(
    List<(String, Uint8List?)> loose,
    List<FileEntry> metadata,
  ) {
    final byName = {for (final item in loose) baseName(item.$1): item};
    return _readBounded([
      for (final entry in metadata)
        if (byName[entry.path] case final item?)
          () =>
              _access.within(item.$2, () => _entry(entry.path, File(item.$1))),
    ]);
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

  Future<List<FileEntry>> _walkMetadata(
    Directory directory,
    String prefix,
  ) async {
    final files = <FileEntry>[];
    final entries = await directory.list(followLinks: false).toList();
    for (final entry in entries) {
      final name = baseName(entry.path);
      final path = '$prefix$name';
      if (entry is Directory) {
        if (HiddenFolders.isHidden(name)) continue;
        files.addAll(await _walkMetadata(entry, '$path/'));
      } else if (entry is File && MarkdownFile.isMarkdown(name)) {
        files.add(
          FileEntry(path, null, sourceId: localDocumentSourceId(entry.path)),
        );
      }
    }
    return files;
  }

  static Future<List<FileEntry>> _readBounded(
    List<Future<FileEntry> Function()> reads,
  ) async {
    if (reads.isEmpty) return const [];
    final results = List<FileEntry?>.filled(reads.length, null);
    var next = 0;

    Future<void> worker() async {
      while (next < reads.length) {
        final index = next++;
        results[index] = await reads[index]();
      }
    }

    final workerCount = reads.length < _maximumConcurrentReads
        ? reads.length
        : _maximumConcurrentReads;
    await Future.wait(List.generate(workerCount, (_) => worker()));
    return results.cast<FileEntry>();
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
