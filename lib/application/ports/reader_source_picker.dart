import 'folder_scanner.dart';
import 'markdown_scanner.dart';

/// One reader source selected by the platform's Open dialog.
sealed class ReaderSourceSelection {
  const ReaderSourceSelection();
}

final class FolderSourceSelection extends ReaderSourceSelection {
  final FolderRef ref;

  const FolderSourceSelection(this.ref);
}

final class MarkdownSourceSelection extends ReaderSourceSelection {
  final MarkdownRef ref;

  const MarkdownSourceSelection(this.ref);
}

/// Selects folders and Markdown files without exposing platform paths.
abstract interface class ReaderSourcePicker {
  Future<List<ReaderSourceSelection>> pick();
}
