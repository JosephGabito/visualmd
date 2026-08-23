// ignore_for_file: prefer_initializing_formals — private fields keep public constructor names.
import '../../domain/library/document_id.dart';
import '../../domain/search/search_result.dart';
import '../ports/document_search.dart';
import '../ports/library_repository.dart';
import 'read_document.dart';

/// Use case: search the open library, optionally within one document.
final class SearchDocuments {
  final LibraryRepository _repository;
  final DocumentSearch _search;

  const SearchDocuments({
    required LibraryRepository repository,
    required DocumentSearch search,
  }) : _repository = repository,
       _search = search;

  Future<List<DocumentSearchResult>> execute(
    String text, {
    DocumentId? within,
  }) async {
    if (text.isEmpty) return const [];
    final library = await _repository.current();
    if (library == null) throw const NoLibraryOpen();

    if (within == null) {
      return _search.find(SearchQuery(text), library.documents);
    }
    final document = library.find(within);
    if (document == null) throw DocumentNotFound(within);
    return _search.find(SearchQuery(text), [document]);
  }
}
