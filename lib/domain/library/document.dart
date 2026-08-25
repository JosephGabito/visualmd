import '../reading/document_outline.dart';
import 'document_id.dart';
import 'document_source_id.dart';
import 'markdown_file.dart';

// ignore_for_file: prefer_initializing_formals — public names describe the source contract.

/// The identity and shelf metadata of one markdown file in the library.
///
/// Real folder scans deliberately leave [loadedContent] empty. Source text is
/// reading-session state, not library state: the application loads it when the
/// document is opened and keeps only a bounded set of recent readings. The
/// optional content remains useful for bundled and in-memory sources whose
/// bytes already belong to the process.
final class Document {
  final DocumentId id;
  final DocumentSourceId? sourceId;
  final String? _content;
  final String? _indexedTitle;

  Document({required this.id, String? content, this.sourceId, String? title})
    : _content = content,
      _indexedTitle = title {
    if (!MarkdownFile.isMarkdown(id.fileName)) {
      throw ArgumentError.value(id.path, 'id', 'is not a markdown file');
    }
  }

  String get fileName => id.fileName;

  bool get isReadme => fileName.toLowerCase().startsWith('readme');

  /// Source bundled with an in-memory document, absent from normal scans.
  String? get loadedContent => _content;

  /// Kept for source-backed domain fixtures and document validators.
  /// Production readers should load through the application source reader.
  String get content =>
      _content ??
      (throw StateError('Source for ${id.path} has not been loaded'));

  /// Parsed lazily for source-backed domain fixtures.
  late final DocumentOutline outline = DocumentOutline.parse(content);

  String? get indexedTitle => _indexedTitle;

  /// What the reader sees on the shelf: the document's own title if it
  /// declares one, otherwise its file name.
  String get title =>
      _indexedTitle ??
      (_content == null ? null : outline.title) ??
      MarkdownFile.stripExtension(fileName);

  /// A transient source-backed view used by readers and streaming search.
  Document withContent(String content) => Document(
    id: id,
    content: content,
    sourceId: sourceId,
    title: _indexedTitle,
  );

  @override
  String toString() => 'Document($id)';
}
