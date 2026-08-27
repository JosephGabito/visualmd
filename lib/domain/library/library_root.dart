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

  LibraryRoot replaceDocument(Document document) =>
      applyDocumentChanges({document.id: document});

  /// Inserts, replaces, or removes documents through only their changed paths.
  LibraryRoot applyDocumentChanges(Map<DocumentId, Document?> changes) {
    if (changes.keys.any((documentId) => documentId.rootId != id)) {
      throw ArgumentError.value(changes.keys, 'changes', 'must belong to $id');
    }
    return LibraryRoot(
      id: id,
      name: name,
      folder: folder.applyDocumentChanges(changes),
    );
  }

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
