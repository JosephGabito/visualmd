import '../../domain/library/document.dart';
import '../../domain/library/document_id.dart';
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

/// A search adapter which retains derived visible-text projections.
///
/// The application uses this capability to avoid loading source which the
/// adapter has already projected. Invalidation follows document identity so a
/// changed source cannot answer from an old projection, while an unchanged
/// library can refine queries without touching source bytes again.
abstract interface class DocumentSearchIndex implements DocumentSearch {
  bool contains(DocumentId id);

  void invalidate(Iterable<DocumentId> ids);

  void retain(Iterable<DocumentId> ids);

  void clear();
}
