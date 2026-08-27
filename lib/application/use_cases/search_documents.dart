// ignore_for_file: prefer_initializing_formals — private fields keep public constructor names.
import '../document_source_reader.dart';
import '../../domain/library/document.dart';
import '../../domain/library/document_id.dart';
import '../../domain/library/library.dart';
import '../../domain/search/search_result.dart';
import '../ports/document_search.dart';
import '../ports/library_repository.dart';
import 'read_document.dart';

/// Use case: search the open library, optionally within one document.
final class SearchDocuments {
  final LibraryRepository _repository;
  final DocumentSearch _search;
  final DocumentSourceReader? _sources;
  var _request = 0;

  SearchDocuments({
    required LibraryRepository repository,
    required DocumentSearch search,
    DocumentSourceReader? sources,
  }) : _repository = repository,
       _search = search,
       _sources = sources;

  Future<List<DocumentSearchResult>> execute(
    String text, {
    DocumentId? within,
  }) async {
    final request = ++_request;
    if (text.isEmpty) return const [];
    final library = await _repository.current();
    if (request != _request) return const [];
    if (library == null) throw const NoLibraryOpen();

    final documents = within == null
        ? library.documents
        : [library.find(within) ?? (throw DocumentNotFound(within))];
    final query = SearchQuery(text);
    final results = <DocumentSearchResult>[];
    final index = switch (_search) {
      DocumentSearchIndex indexed => indexed,
      _ => null,
    };
    // Whole-library search deliberately does not warm the reading cache. One
    // uncached source is loaded, projected, and released before the next one
    // is read. Query refinement reuses the adapter's byte-bounded projection.
    for (final document in documents) {
      final indexed = index?.contains(document.id) ?? false;
      final searchable = indexed
          ? document
          : document.withContent(
              document.loadedContent ?? (await _loadSource(library, document)),
            );
      if (request != _request) return const [];
      final found = await _search.find(query, [searchable]);
      if (request != _request) return const [];
      results.addAll([
        for (final result in found)
          DocumentSearchResult(document: document, matches: result.matches),
      ]);
    }
    return results;
  }

  Future<String> _loadSource(Library library, Document document) {
    final reader = _sources;
    if (reader == null) throw DocumentSourceUnavailable(document);
    return reader.read(library, document);
  }

  /// Evicts projections whose source bytes may have changed.
  void invalidate(Iterable<DocumentId> ids) {
    _request++;
    final search = _search;
    if (search is DocumentSearchIndex) search.invalidate(ids);
  }

  /// Releases projections for documents no longer present in the library.
  void retain(Iterable<DocumentId> ids) {
    _request++;
    final search = _search;
    if (search is DocumentSearchIndex) search.retain(ids);
  }

  void clear() {
    _request++;
    final search = _search;
    if (search is DocumentSearchIndex) search.clear();
  }
}
