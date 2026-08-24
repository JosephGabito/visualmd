// ignore_for_file: prefer_initializing_formals — private fields keep public constructor names.
import 'package:characters/characters.dart';

import '../../application/ports/document_parser.dart';
import '../../application/ports/document_search.dart';
import '../../domain/library/document.dart';
import '../../domain/search/search_result.dart';

/// Searches rendered document text with Dart's portable regular-expression
/// engine. The expression is escaped, so reader input is always literal.
final class LiteralDocumentSearch implements DocumentSearch {
  final DocumentParser _parser;
  final _text = <Document, String>{};

  LiteralDocumentSearch({required DocumentParser parser}) : _parser = parser;

  @override
  Future<List<DocumentSearchResult>> find(
    SearchQuery query,
    Iterable<Document> documents,
  ) async {
    final pattern = RegExp(
      RegExp.escape(query.text),
      caseSensitive: false,
      unicode: true,
    );
    final results = <DocumentSearchResult>[];
    for (final document in documents) {
      final text = _text.putIfAbsent(
        document,
        () => _parser.parse(document.content).text,
      );
      final matches = [
        for (final match in pattern.allMatches(text))
          TextMatch(
            start: match.start,
            end: match.end,
            excerpt: _excerpt(text, match.start, match.end),
          ),
      ];
      if (matches.isNotEmpty) {
        results.add(DocumentSearchResult(document: document, matches: matches));
      }
    }
    return results;
  }

  static String _excerpt(String text, int start, int end) {
    const reach = 46;
    final roughFrom = start > reach ? start - reach : 0;
    final roughTo = end + reach < text.length ? end + reach : text.length;
    final range = CharacterRange.at(text, roughFrom, roughTo);
    final from = range.stringBeforeLength;
    final to = text.length - range.stringAfterLength;
    final words = text
        .substring(from, to)
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return '${from > 0 ? '…' : ''}$words${to < text.length ? '…' : ''}';
  }
}
