import 'document.dart';
import 'document_id.dart';
import 'natural_order.dart';

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
    final segments = id.segments;
    var folder = this;
    for (final segment in segments.take(segments.length - 1)) {
      Folder? child;
      for (final candidate in folder.folders) {
        if (candidate.name == segment) {
          child = candidate;
          break;
        }
      }
      if (child == null) return null;
      folder = child;
    }
    for (final document in folder.documents) {
      if (document.fileName == segments.last && document.id == id) {
        return document;
      }
    }
    return null;
  }

  /// Applies path-addressed document changes while sharing untouched branches.
  ///
  /// The receiver is the root folder. Each changed ancestor is copied once;
  /// directories outside those paths retain object identity and are neither
  /// traversed nor resorted.
  Folder applyDocumentChanges(Map<DocumentId, Document?> changes) {
    if (changes.isEmpty) return this;
    final root = _FolderChangeNode();
    for (final entry in changes.entries) {
      var node = root;
      final segments = entry.key.segments;
      for (final segment in segments.take(segments.length - 1)) {
        node = node.children.putIfAbsent(segment, _FolderChangeNode.new);
      }
      node.documents[segments.last] = entry.value;
    }
    return _applyChanges(root);
  }

  Folder _applyChanges(_FolderChangeNode changes) {
    var nextDocuments = documents;
    if (changes.documents.isNotEmpty) {
      final byName = {
        for (final document in documents) document.fileName: document,
      };
      for (final entry in changes.documents.entries) {
        final replacement = entry.value;
        if (replacement == null) {
          byName.remove(entry.key);
        } else {
          byName[entry.key] = replacement;
        }
      }
      nextDocuments = byName.values.toList()..sort(_compareDocuments);
    }

    var nextFolders = folders;
    if (changes.children.isNotEmpty) {
      final byName = {for (final folder in folders) folder.name: folder};
      for (final entry in changes.children.entries) {
        final existing = byName[entry.key];
        final child = (existing ?? _emptyChild(entry.key))._applyChanges(
          entry.value,
        );
        if (child.documents.isEmpty && child.folders.isEmpty) {
          byName.remove(entry.key);
        } else {
          byName[entry.key] = child;
        }
      }
      nextFolders = byName.values.toList()
        ..sort((a, b) => NaturalOrder.compare(a.name, b.name));
    }

    if (identical(nextDocuments, documents) &&
        identical(nextFolders, folders)) {
      return this;
    }
    return Folder(
      name: name,
      path: path,
      folders: nextFolders,
      documents: nextDocuments,
    );
  }

  Folder _emptyChild(String childName) => Folder(
    name: childName,
    path: path.isEmpty ? childName : '$path/$childName',
    folders: const [],
    documents: const [],
  );
}

int _compareDocuments(Document a, Document b) {
  if (a.isReadme != b.isReadme) return a.isReadme ? -1 : 1;
  return NaturalOrder.compare(a.fileName, b.fileName);
}

final class _FolderChangeNode {
  final Map<String, _FolderChangeNode> children = {};
  final Map<String, Document?> documents = {};
}
