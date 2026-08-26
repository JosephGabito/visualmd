import 'dart:io';
import 'dart:typed_data';

import '../../application/ports/folder_scanner.dart';
import '../../application/ports/markdown_scanner.dart';
import '../../application/ports/shelf_source_actions.dart';
import 'desktop_links.dart';
import 'local_folder.dart';
import 'local_markdown.dart';
import 'scoped_access.dart';

/// Resolves opaque shelf identities back to paths on this desktop only.
final class DesktopShelfSourceActions implements ShelfSourceActions {
  static const _standalonePrefix = 'standalone-markdown:';

  final LocalFolderRegistry _folders;
  final LocalMarkdownRegistry _markdowns;
  final ScopedAccess _access;

  const DesktopShelfSourceActions(
    this._folders,
    this._markdowns, {
    required this._access,
  });

  @override
  String get revealLabel => Platform.isMacOS
      ? 'Reveal in Finder'
      : Platform.isWindows
      ? 'Show in File Explorer'
      : 'Show in file manager';

  @override
  String? absolutePath(ShelfSourceLocation source) => _resolved(source)?.path;

  @override
  Future<void> reveal(ShelfSourceLocation source) async {
    final resolved = _resolved(source);
    if (resolved == null) return;
    await _access.within(
      resolved.bookmark,
      () => revealInFileManager(resolved.path),
    );
  }

  ({String path, Uint8List? bookmark})? _resolved(ShelfSourceLocation source) =>
      switch (source) {
        ShelfFolderLocation(:final rootId, :final relativePath) => _folderPath(
          rootId.value,
          relativePath,
        ),
        ShelfDocumentLocation(:final documentId) =>
          documentId.rootId.value.startsWith(_standalonePrefix)
              ? _standalonePath(
                  documentId.rootId.value.substring(_standalonePrefix.length),
                )
              : _folderPath(documentId.rootId.value, documentId.path),
      };

  ({String path, Uint8List? bookmark})? _standalonePath(String id) {
    final markdown = _markdowns.lookup(MarkdownRef(id: id, name: ''));
    if (markdown == null) return null;
    return (
      path: File(markdown.path).absolute.path,
      bookmark: markdown.bookmark,
    );
  }

  ({String path, Uint8List? bookmark})? _folderPath(
    String id,
    String relativePath,
  ) {
    final folder = _folders.lookup(FolderRef(id: id, name: ''));
    return switch (folder) {
      LocalDirectory(:final path, :final bookmark) => switch (_beneath(
        path,
        relativePath,
      )) {
        final resolved? => (path: resolved, bookmark: bookmark),
        null => null,
      },
      LocalFiles(files: final files) => _looseFile(files, relativePath),
      null => null,
    };
  }

  static String? _beneath(String root, String relativePath) {
    if (relativePath == '.') return Directory(root).absolute.path;
    final segments = relativePath.split('/');
    // Source locations normally come from the scanner, but containment belongs
    // at the filesystem edge. That keeps a future caller from turning this
    // convenience port into an escape from the opened root.
    if (relativePath.isEmpty ||
        relativePath.startsWith('/') ||
        relativePath.startsWith(r'\') ||
        RegExp(r'^[A-Za-z]:').hasMatch(relativePath) ||
        segments.any(
          (segment) =>
              segment.isEmpty ||
              segment == '.' ||
              segment == '..' ||
              segment.contains(r'\'),
        )) {
      return null;
    }
    return File([root, ...relativePath.split('/')].join(Platform.pathSeparator))
        .absolute
        .path;
  }

  static ({String path, Uint8List? bookmark})? _looseFile(
    List<(String, Uint8List?)> files,
    String relativePath,
  ) {
    if (relativePath == '.') return null;
    for (final (path, bookmark) in files) {
      if (baseName(path) == relativePath) {
        return (path: File(path).absolute.path, bookmark: bookmark);
      }
    }
    return null;
  }
}
