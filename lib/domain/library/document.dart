import '../reading/document_outline.dart';
import 'document_id.dart';
import 'document_source_id.dart';
import 'markdown_file.dart';

/// A markdown file in the library, with its full content.
final class Document {
  final DocumentId id;
  final String content;
  final DocumentSourceId? sourceId;

  Document({required this.id, required this.content, this.sourceId}) {
    if (!MarkdownFile.isMarkdown(id.fileName)) {
      throw ArgumentError.value(id.path, 'id', 'is not a markdown file');
    }
  }

  String get fileName => id.fileName;

  bool get isReadme => fileName.toLowerCase().startsWith('readme');

  /// Parsed lazily: the outline is needed both for the title shown on the
  /// shelf and for reading, and parsing once is enough.
  late final DocumentOutline outline = DocumentOutline.parse(content);

  /// What the reader sees on the shelf: the document's own title if it
  /// declares one, otherwise its file name.
  String get title => outline.title ?? MarkdownFile.stripExtension(fileName);

  @override
  String toString() => 'Document($id)';
}
