import 'document.dart';
import 'document_id.dart';
import 'document_source_id.dart';
import 'library_root.dart';
import 'library_root_id.dart';

/// Aggregate root: the ordered folders and documents in this reading session.
final class Library {
  final List<LibraryRoot> roots;
  final List<Document> markdowns;

  Library({
    required Iterable<LibraryRoot> roots,
    Iterable<Document> markdowns = const [],
  }) : roots = List.unmodifiable(roots),
       markdowns = List.unmodifiable(markdowns) {
    final ids = this.roots.map((root) => root.id).toSet();
    if (ids.length != this.roots.length) {
      throw ArgumentError.value(roots, 'roots', 'must have unique identities');
    }
    final documentIds = this.markdowns.map((document) => document.id).toSet();
    if (documentIds.length != this.markdowns.length) {
      throw ArgumentError.value(
        markdowns,
        'markdowns',
        'must have unique identities',
      );
    }
    if (this.markdowns.any((document) => ids.contains(document.id.rootId))) {
      throw ArgumentError.value(
        markdowns,
        'markdowns',
        'must not share a folder root identity',
      );
    }
  }

  Library.empty() : roots = const [], markdowns = const [];

  bool get isEmpty => roots.isEmpty && markdowns.isEmpty;

  int get documentCount =>
      markdowns.length + roots.fold(0, (sum, root) => sum + root.documentCount);

  int get folderDocumentCount =>
      roots.fold(0, (sum, root) => sum + root.documentCount);

  Iterable<Document> get documents sync* {
    yield* markdowns;
    for (final root in roots) {
      yield* root.documents;
    }
  }

  LibraryRoot? rootById(LibraryRootId id) {
    for (final root in roots) {
      if (root.id == id) return root;
    }
    return null;
  }

  Document? find(DocumentId id) {
    for (final document in markdowns) {
      if (document.id == id) return document;
    }
    return rootById(id.rootId)?.find(id);
  }

  Document? findBySource(DocumentSourceId sourceId) {
    for (final document in documents) {
      if (document.sourceId == sourceId) return document;
    }
    return null;
  }

  /// Appends a new root, or refreshes an existing root without moving it.
  Library addOrReplace(LibraryRoot root) {
    final index = roots.indexWhere((candidate) => candidate.id == root.id);
    if (index < 0) {
      return Library(roots: [...roots, root], markdowns: markdowns);
    }
    final next = [...roots]..[index] = root;
    return Library(roots: next, markdowns: markdowns);
  }

  Library addOrReplaceMarkdown(Document document, {int? atIndex}) {
    final index = markdowns.indexWhere(
      (candidate) => candidate.id == document.id,
    );
    if (index < 0) {
      final next = [...markdowns];
      next.insert(atIndex?.clamp(0, next.length) ?? next.length, document);
      return Library(roots: roots, markdowns: next);
    }
    final next = [...markdowns]..[index] = document;
    return Library(roots: roots, markdowns: next);
  }

  /// Replaces one existing document while preserving its place on the shelf.
  Library replaceDocument(Document document) {
    final markdownIndex = markdowns.indexWhere(
      (candidate) => candidate.id == document.id,
    );
    if (markdownIndex >= 0) {
      final next = [...markdowns]..[markdownIndex] = document;
      return Library(roots: roots, markdowns: next);
    }
    final rootIndex = roots.indexWhere((root) => root.id == document.id.rootId);
    if (rootIndex < 0 || roots[rootIndex].find(document.id) == null) {
      return this;
    }
    final next = [...roots]
      ..[rootIndex] = roots[rootIndex].replaceDocument(document);
    return Library(roots: next, markdowns: markdowns);
  }

  Library remove(LibraryRootId id) => Library(
    roots: roots.where((root) => root.id != id),
    markdowns: markdowns,
  );

  Library removeMarkdown(DocumentId id) => Library(
    roots: roots,
    markdowns: markdowns.where((document) => document.id != id),
  );

  Library move(LibraryRootId id, int toIndex) {
    final fromIndex = roots.indexWhere((root) => root.id == id);
    if (fromIndex < 0) return this;
    final bounded = toIndex.clamp(0, roots.length - 1);
    if (fromIndex == bounded) return this;
    final next = [...roots];
    final root = next.removeAt(fromIndex);
    next.insert(bounded, root);
    return Library(roots: next, markdowns: markdowns);
  }

  Document? get openingDocument {
    for (final root in roots) {
      final document = root.openingDocument;
      if (document != null) return document;
    }
    return markdowns.isEmpty ? null : markdowns.first;
  }
}
