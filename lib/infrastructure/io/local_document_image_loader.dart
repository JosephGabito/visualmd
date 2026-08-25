// ignore_for_file: prefer_initializing_formals — the public name describes the dependency; the field stays private.

import 'dart:io';
import 'dart:typed_data';

import '../../application/ports/document_image_loader.dart';
import '../../application/ports/folder_scanner.dart';
import '../../application/ports/markdown_scanner.dart';
import '../../domain/library/document_id.dart';
import 'local_folder.dart';
import 'local_markdown.dart';
import 'scoped_access.dart';

/// Reads document-relative images from the local source the user authorised.
final class LocalDocumentImageLoader implements DocumentImageLoader {
  static const _standalonePrefix = 'standalone-markdown:';

  final LocalFolderRegistry _folders;
  final LocalMarkdownRegistry _markdown;
  final ScopedAccess _access;

  const LocalDocumentImageLoader(
    this._folders,
    this._markdown, {
    ScopedAccess access = const OpenAccess(),
  }) : _access = access;

  @override
  Future<Uint8List?> load(DocumentId document, String source) async {
    final relative = DocumentImagePath.resolve(
      documentPath: document.path,
      source: source,
    );
    if (relative == null) return null;

    final root = document.rootId.value;
    if (root.startsWith(_standalonePrefix)) {
      final id = root.substring(_standalonePrefix.length);
      final markdown = _markdown.lookup(MarkdownRef(id: id, name: ''));
      if (markdown == null) return null;
      return _readBeneath(
        File(markdown.path).parent.path,
        relative,
        markdown.bookmark,
      );
    }

    final folder = _folders.lookup(FolderRef(id: root, name: ''));
    return switch (folder) {
      LocalDirectory(:final path, :final bookmark) => _readBeneath(
        path,
        relative,
        bookmark,
      ),
      LocalFiles(:final files) => _readLoose(document, relative, files),
      null => null,
    };
  }

  Future<Uint8List?> _readLoose(
    DocumentId document,
    String relative,
    List<(String, Uint8List?)> files,
  ) async {
    final markdown = files.where(
      (entry) => baseName(entry.$1) == document.path,
    );
    if (markdown.isEmpty) return null;
    final target = localMarkdownIdentity(_beside(markdown.first.$1, relative));
    for (final (path, bookmark) in files) {
      if (localMarkdownIdentity(path) == target) {
        return _read(File(path), bookmark);
      }
    }
    return null;
  }

  Future<Uint8List?> _read(File file, Uint8List? bookmark) async {
    try {
      return await _access.within(bookmark, () async {
        if (!await file.exists()) return null;
        return file.readAsBytes();
      });
    } on FileSystemException {
      return null;
    }
  }

  Future<Uint8List?> _readBeneath(
    String root,
    String relative,
    Uint8List? bookmark,
  ) async {
    try {
      return await _access.within(bookmark, () async {
        final canonicalRoot = await Directory(root).resolveSymbolicLinks();
        final canonicalFile = await File(_beneath(root, relative))
            .resolveSymbolicLinks();
        if (!_isWithin(canonicalRoot, canonicalFile)) return null;
        return File(canonicalFile).readAsBytes();
      });
    } on FileSystemException {
      return null;
    }
  }
}

bool _isWithin(String root, String candidate) {
  final canonicalRoot = localMarkdownIdentity(root);
  final canonicalCandidate = localMarkdownIdentity(candidate);
  return canonicalCandidate.startsWith(
    '$canonicalRoot${Platform.pathSeparator}',
  );
}

String _beneath(String root, String relative) =>
    [root, ...relative.split('/')].join(Platform.pathSeparator);

String _beside(String markdown, String relative) => [
  File(markdown).parent.path,
  ...relative.split('/'),
].join(Platform.pathSeparator);
