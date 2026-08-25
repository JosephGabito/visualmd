// ignore_for_file: prefer_initializing_formals — private fields stay private; named params stay public.
import 'dart:collection';

import '../document_source_reader.dart';
import '../../domain/library/document.dart';
import '../../domain/library/document_id.dart';
import '../../domain/library/library.dart';
import '../../domain/reading/document_outline.dart';
import '../../domain/reading/content/document_content.dart';
import '../ports/document_parser.dart';
import '../ports/library_repository.dart';

/// What the reader gets when opening a document: the document, the structure
/// to navigate it by, and the blocks to set on the page.
final class DocumentReading {
  final Document document;
  final String source;
  final DocumentOutline outline;
  final DocumentContent content;

  const DocumentReading({
    required this.document,
    this.source = '',
    required this.outline,
    required this.content,
  });
}

final class NoLibraryOpen implements Exception {
  const NoLibraryOpen();

  @override
  String toString() => 'NoLibraryOpen';
}

final class DocumentNotFound implements Exception {
  final DocumentId id;
  const DocumentNotFound(this.id);

  @override
  String toString() => 'DocumentNotFound: $id';
}

/// Use case: read a document from the current library.
final class ReadDocument {
  static const cacheCapacity = 10;

  final LibraryRepository _repository;
  final DocumentParser _parser;
  final DocumentSourceReader? _sources;
  final LinkedHashMap<DocumentId, DocumentReading> _cache = LinkedHashMap();
  final Map<DocumentId, Future<DocumentReading>> _inFlight = {};
  final Map<DocumentId, int> _invalidations = {};
  var _generation = 0;

  ReadDocument({
    required LibraryRepository repository,
    required DocumentParser parser,
    DocumentSourceReader? sources,
  }) : _repository = repository,
       _parser = parser,
       _sources = sources;

  Future<DocumentReading> execute(DocumentId id) async {
    final library = await _repository.current();
    if (library == null) throw const NoLibraryOpen();
    final document = library.find(id);
    if (document == null) throw DocumentNotFound(id);

    final cached = _cache.remove(id);
    if (cached != null) {
      _cache[id] = cached;
      return cached;
    }

    final existing = _inFlight[id];
    if (existing != null) return existing;
    final generation = _generation;
    final invalidation = _invalidations[id] ?? 0;
    final loading = _load(library, document);
    _inFlight[id] = loading;
    try {
      final reading = await loading;
      if (_generation == generation &&
          (_invalidations[id] ?? 0) == invalidation) {
        _cache[id] = reading;
        while (_cache.length > cacheCapacity) {
          _cache.remove(_cache.keys.first);
        }
      }
      return reading;
    } finally {
      if (identical(_inFlight[id], loading)) _inFlight.remove(id);
    }
  }

  Future<DocumentReading> _load(Library library, Document document) async {
    final embedded = document.loadedContent;
    final reader = _sources;
    final source =
        embedded ??
        (reader == null
            ? throw DocumentSourceUnavailable(document)
            : await reader.read(library, document));
    final loaded = document.withContent(source);
    return DocumentReading(
      document: loaded,
      source: source,
      outline: loaded.outline,
      content: _parser.parse(source),
    );
  }

  /// Source-change events are invalidations: cached readings must not survive
  /// them even when a path and physical identity remain unchanged.
  void invalidate(Iterable<DocumentId> ids) {
    for (final id in ids) {
      _cache.remove(id);
      _inFlight.remove(id);
      _invalidations[id] = (_invalidations[id] ?? 0) + 1;
    }
  }

  /// Releases readings whose source no longer belongs to the open library.
  void retain(Iterable<DocumentId> ids) {
    final retained = ids.toSet();
    invalidate([
      for (final id in {..._cache.keys, ..._inFlight.keys})
        if (!retained.contains(id)) id,
    ]);
  }

  void clear() {
    _generation++;
    _cache.clear();
    _inFlight.clear();
    _invalidations.clear();
  }
}
