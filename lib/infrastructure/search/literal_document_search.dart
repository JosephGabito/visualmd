// ignore_for_file: prefer_initializing_formals — private fields keep public constructor names.
import 'dart:collection';

import 'package:characters/characters.dart';

import '../../application/ports/document_parser.dart';
import '../../application/ports/document_search.dart';
import '../../domain/library/document.dart';
import '../../domain/library/document_id.dart';
import '../../domain/search/search_result.dart';

/// Searches rendered document text with Dart's portable regular-expression
/// engine. The expression is escaped, so reader input is always literal.
final class LiteralDocumentSearch implements DocumentSearchIndex {
  static const defaultMaximumRetainedBytes = 64 * 1024 * 1024;

  final DocumentParser _parser;
  final int maximumRetainedBytes;
  final LinkedHashMap<DocumentId, _SearchProjection> _projections =
      LinkedHashMap();
  var _retainedBytes = 0;

  LiteralDocumentSearch({
    required DocumentParser parser,
    this.maximumRetainedBytes = defaultMaximumRetainedBytes,
  }) : assert(maximumRetainedBytes >= 0),
       _parser = parser;

  int get retainedBytes => _retainedBytes;

  int get retainedCount => _projections.length;

  @override
  bool contains(DocumentId id) => _projections.containsKey(id);

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
      final text = _projectionFor(document).text;
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

  _SearchProjection _projectionFor(Document document) {
    final retained = _projections.remove(document.id);
    if (retained != null) {
      _projections[document.id] = retained;
      return retained;
    }

    final source = document.loadedContent;
    if (source == null) {
      throw StateError(
        'Search projection for ${document.id.path} has not been prepared',
      );
    }
    final projection = _SearchProjection(_parser.parse(source).text);
    if (projection.retainedBytes > maximumRetainedBytes) return projection;

    while (_projections.isNotEmpty &&
        _retainedBytes + projection.retainedBytes > maximumRetainedBytes) {
      final oldest = _projections.keys.first;
      _retainedBytes -= _projections.remove(oldest)!.retainedBytes;
    }
    _projections[document.id] = projection;
    _retainedBytes += projection.retainedBytes;
    return projection;
  }

  @override
  void invalidate(Iterable<DocumentId> ids) {
    for (final id in ids) {
      final removed = _projections.remove(id);
      if (removed != null) _retainedBytes -= removed.retainedBytes;
    }
  }

  @override
  void retain(Iterable<DocumentId> ids) {
    final retained = ids.toSet();
    final removed = _projections.keys
        .where((id) => !retained.contains(id))
        .toList(growable: false);
    invalidate(removed);
  }

  @override
  void clear() {
    _projections.clear();
    _retainedBytes = 0;
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

final class _SearchProjection {
  final String text;

  const _SearchProjection(this.text);

  /// Dart exposes no portable heap-size API. UTF-16 payload plus a small,
  /// conservative object allowance gives the cache a deterministic ceiling.
  int get retainedBytes => (text.length * 2) + 64;
}
