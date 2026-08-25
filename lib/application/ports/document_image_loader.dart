import 'dart:typed_data';

import '../../domain/library/document_id.dart';

/// Reads one image referenced by a document from the source the user opened.
///
/// The application names the document and the authored destination; platform
/// adapters decide how an authorised folder handle, bookmark, or file list can
/// satisfy it. A missing or unreachable image returns null so the page can use
/// the author's alternative text without turning one bad asset into a failed
/// document read.
abstract interface class DocumentImageLoader {
  Future<Uint8List?> load(DocumentId document, String source);
}

/// Resolves a Markdown image destination against its document directory.
///
/// The result is portable and rooted at the opened library folder. Parent
/// segments may move within that folder, but never above it; schemes,
/// authorities, absolute paths, and encoded path separators are not local
/// document assets.
abstract final class DocumentImagePath {
  static String? resolve({
    required String documentPath,
    required String source,
  }) {
    final portable = source.replaceAll('\\', '/');
    final uri = Uri.tryParse(portable);
    if (uri == null ||
        uri.hasScheme ||
        uri.hasAuthority ||
        portable.startsWith('/') ||
        uri.path.isEmpty) {
      return null;
    }

    final documentSegments = documentPath.replaceAll('\\', '/').split('/')
      ..removeLast();
    final resolved = <String>[...documentSegments];
    for (final raw in uri.path.split('/')) {
      final segment = _decode(raw);
      if (segment == null || segment.contains('/') || segment.contains('\\')) {
        return null;
      }
      if (segment.isEmpty || segment == '.') continue;
      if (segment == '..') {
        if (resolved.isEmpty) return null;
        resolved.removeLast();
      } else {
        resolved.add(segment);
      }
    }
    return resolved.isEmpty ? null : resolved.join('/');
  }

  static String? _decode(String segment) {
    try {
      return Uri.decodeComponent(segment);
    } on FormatException {
      return null;
    }
  }
}
