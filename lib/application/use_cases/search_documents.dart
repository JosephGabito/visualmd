// ignore_for_file: prefer_initializing_formals — private fields keep public constructor names.
import '../document_source_reader.dart';
import '../../domain/library/document_id.dart';
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
    // Whole-library search deliberately does not warm the reading cache. One
    // source is loaded, searched, and released before the next one is read.
    for (final document in documents) {
      final reader = _sources;
      final source =
          document.loadedContent ??
          (reader == null
              ? throw DocumentSourceUnavailable(document)
              : await reader.read(library, document));
      if (request != _request) return const [];
      final found = await _search.find(query, [document.withContent(source)]);
      if (request != _request) return const [];
      results.addAll([
        for (final result in found)
          DocumentSearchResult(document: document, matches: result.matches),
      ]);
    }
    return results;
  }
}
