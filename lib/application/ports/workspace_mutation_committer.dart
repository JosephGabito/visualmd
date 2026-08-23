import '../../domain/library/document_id.dart';
import '../../domain/library/library.dart';
import 'folder_scanner.dart';
import 'markdown_scanner.dart';

/// Commits durable workspace intent before a Library mutation becomes visible.
abstract interface class WorkspaceMutationCommitter {
  Future<void> folderAdded(FolderRef ref, Library library, DocumentId? active);

  Future<void> markdownAdded(
    MarkdownRef ref,
    Library library,
    DocumentId active, {
    required bool added,
  });

  Future<void> libraryChanged(Library library, DocumentId? active);
}
