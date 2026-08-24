import '../../domain/library/document_source_id.dart';
import 'folder_scanner.dart';

/// One Markdown file read from inside an already-open folder source.
final class ScannedFolderDocument {
  final String relativePath;
  final String content;
  final DocumentSourceId? sourceId;

  const ScannedFolderDocument({
    required this.relativePath,
    required this.content,
    required this.sourceId,
  });
}

/// Reads one invalidated document without scanning every file in its root.
///
/// A null result means the path no longer names a readable Markdown file. The
/// aggregate can then remove it without confusing deletion with a read error.
abstract interface class FolderDocumentScanner {
  Future<ScannedFolderDocument?> scanDocument(
    FolderRef folder,
    String relativePath,
  );
}
