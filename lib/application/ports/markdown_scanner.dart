import '../../domain/library/document_source_id.dart';

/// One markdown file the reader offered directly rather than through a folder.
final class MarkdownRef {
  final String id;
  final String name;

  const MarkdownRef({required this.id, required this.name});

  @override
  bool operator ==(Object other) => other is MarkdownRef && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// The text and opaque physical identity read from a [MarkdownRef].
final class ScannedMarkdown {
  final String name;
  final String content;
  final DocumentSourceId? sourceId;

  const ScannedMarkdown({
    required this.name,
    required this.content,
    required this.sourceId,
  });
}

/// Port: reads one directly offered markdown file.
abstract interface class MarkdownScanner {
  Future<ScannedMarkdown> scan(MarkdownRef ref);
}

final class MarkdownUnavailable implements Exception {
  final MarkdownRef ref;

  const MarkdownUnavailable(this.ref);
}
