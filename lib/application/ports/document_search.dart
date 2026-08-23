import '../../domain/library/document.dart';
import '../../domain/search/search_result.dart';

/// Port: finds a literal in the visible text of a set of documents.
///
/// The contract speaks in domain documents and text offsets. Whether matching
/// is a scan, an index, or a platform service belongs to the adapter.
abstract interface class DocumentSearch {
  Future<List<DocumentSearchResult>> find(
    SearchQuery query,
    Iterable<Document> documents,
  );
}
