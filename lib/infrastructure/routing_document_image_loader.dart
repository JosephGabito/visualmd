import 'dart:typed_data';

import '../application/ports/document_image_loader.dart';
import '../domain/library/document_id.dart';

/// Tries the bundled and platform image sources without exposing either one
/// to the page.
final class RoutingDocumentImageLoader implements DocumentImageLoader {
  final List<DocumentImageLoader> _loaders;

  const RoutingDocumentImageLoader(this._loaders);

  @override
  Future<Uint8List?> load(DocumentId document, String source) async {
    for (final loader in _loaders) {
      final bytes = await loader.load(document, source);
      if (bytes != null) return bytes;
    }
    return null;
  }
}
