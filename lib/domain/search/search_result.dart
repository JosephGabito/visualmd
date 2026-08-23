import '../library/document.dart';

/// A non-empty literal the reader is looking for.
final class SearchQuery {
  final String text;

  SearchQuery(this.text) {
    if (text.isEmpty) {
      throw ArgumentError.value(text, 'text', 'must not be empty');
    }
  }
}

/// One occurrence in the plain text a reader sees.
final class TextMatch {
  final int start;
  final int end;
  final String excerpt;

  const TextMatch({
    required this.start,
    required this.end,
    required this.excerpt,
  }) : assert(start >= 0),
       assert(end > start);

  bool overlaps(int from, int to) => start < to && end > from;
}

/// Every occurrence in one document, kept together for a useful result list.
final class DocumentSearchResult {
  final Document document;
  final List<TextMatch> matches;

  const DocumentSearchResult({required this.document, required this.matches});
}
