import 'package:flutter/services.dart';

import '../../application/ports/document_image_loader.dart';
import '../../domain/library/document_id.dart';
import 'sample_folder_scanner.dart';

/// Resolves the sample library's relative artwork from the app bundle.
final class SampleDocumentImageLoader implements DocumentImageLoader {
  const SampleDocumentImageLoader();

  @override
  Future<Uint8List?> load(DocumentId document, String source) async {
    if (document.rootId.value != SampleFolderScanner.ref.id) return null;
    final path = DocumentImagePath.resolve(
      documentPath: document.path,
      source: source,
    );
    if (path != 'images/visual-md-logo.png') return null;
    final data = await rootBundle.load('assets/brand/visual-md-logo.png');
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }
}
