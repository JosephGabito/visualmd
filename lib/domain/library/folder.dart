import 'document.dart';
import 'document_id.dart';

/// A shelf in the library: a folder holding documents and sub-folders.
/// Folders that contain no documents anywhere beneath them are never built.
final class Folder {
  final String name;

  /// Path relative to the library root, `''` for the root itself.
  final String path;
  final List<Folder> folders;
  final List<Document> documents;

  const Folder({
    required this.name,
    required this.path,
    required this.folders,
    required this.documents,
  });

  bool get isRoot => path.isEmpty;

  int get documentCount =>
      documents.length + folders.fold(0, (n, f) => n + f.documentCount);

  /// Depth-first: this folder's documents, then each sub-folder's.
  Iterable<Document> get allDocuments sync* {
    yield* documents;
    for (final folder in folders) {
      yield* folder.allDocuments;
    }
  }

  Document? find(DocumentId id) {
    for (final document in allDocuments) {
      if (document.id == id) return document;
    }
    return null;
  }
}
