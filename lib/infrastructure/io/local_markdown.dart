import 'dart:io';
import 'dart:typed_data';

import '../../domain/library/document_source_id.dart';
import '../markdown_registry.dart';

/// One local markdown file and its optional macOS security-scoped bookmark.
final class LocalMarkdown {
  final String path;
  final Uint8List? bookmark;

  const LocalMarkdown(this.path, {this.bookmark});
}

typedef LocalMarkdownRegistry = MarkdownRegistry<LocalMarkdown>;

String localMarkdownIdentity(String path) {
  final absolute = File(path).absolute.path.replaceAll('\\', '/');
  return Platform.isWindows ? absolute.toLowerCase() : absolute;
}

DocumentSourceId localDocumentSourceId(String path) =>
    DocumentSourceId(localMarkdownIdentity(path));
