// ignore_for_file: prefer_initializing_formals — named parameters describe the composition contract.

import '../domain/library/document.dart';
import '../domain/library/library.dart';
import 'ports/folder_document_scanner.dart';
import 'ports/folder_scanner.dart';
import 'ports/markdown_scanner.dart';

/// Reads one document without making source text part of the library model.
///
/// Folder and standalone identities are application concepts, while the means
/// of reaching their bytes remains behind scanner ports. Keeping this routing
/// here lets reading and search share one source contract without teaching the
/// domain about files, browser handles, or security-scoped bookmarks.
final class DocumentSourceReader {
  static const _standalonePrefix = 'standalone-markdown:';

  final FolderDocumentScanner _folderDocuments;
  final MarkdownScanner _markdowns;

  const DocumentSourceReader({
    required FolderDocumentScanner folderDocuments,
    required MarkdownScanner markdowns,
  }) : _folderDocuments = folderDocuments,
       _markdowns = markdowns;

  Future<String> read(Library library, Document document) async {
    final embedded = document.loadedContent;
    if (embedded != null) return embedded;

    final root = document.id.rootId.value;
    if (root.startsWith(_standalonePrefix)) {
      final ref = MarkdownRef(
        id: root.substring(_standalonePrefix.length),
        name: document.fileName,
      );
      return (await _markdowns.scan(ref)).content;
    }

    final libraryRoot = library.rootById(document.id.rootId);
    if (libraryRoot == null) throw DocumentSourceUnavailable(document);
    final scanned = await _folderDocuments.scanDocument(
      FolderRef(id: root, name: libraryRoot.name),
      document.id.path,
    );
    if (scanned == null) throw DocumentSourceUnavailable(document);
    return scanned.content;
  }
}

final class DocumentSourceUnavailable implements Exception {
  final Document document;

  const DocumentSourceUnavailable(this.document);

  @override
  String toString() => 'DocumentSourceUnavailable: ${document.id}';
}
