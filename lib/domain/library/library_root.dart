import 'document.dart';
import 'document_id.dart';
import 'folder.dart';
import 'library_root_id.dart';

/// One independently opened folder on the library shelf.
final class LibraryRoot {
  final LibraryRootId id;
  final String name;
  final Folder folder;

  const LibraryRoot({
    required this.id,
    required this.name,
    required this.folder,
  });

  int get documentCount => folder.documentCount;

  Iterable<Document> get documents => folder.allDocuments;

  Document? find(DocumentId documentId) =>
      documentId.rootId == id ? folder.find(documentId) : null;

  /// Prefer the folder's README, then the first document in shelf order.
  Document? get openingDocument {
    for (final document in folder.documents) {
      if (document.isReadme) return document;
    }
    for (final document in documents) {
      return document;
    }
    return null;
  }
}
