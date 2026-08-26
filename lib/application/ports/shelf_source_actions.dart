import '../../domain/library/document_id.dart';
import '../../domain/library/library_root_id.dart';

/// One source-backed row whose physical location may be available locally.
sealed class ShelfSourceLocation {
  const ShelfSourceLocation();

  /// Path from the opened root; `.` denotes the root itself.
  String get relativePath;
}

final class ShelfFolderLocation extends ShelfSourceLocation {
  final LibraryRootId rootId;

  @override
  final String relativePath;

  const ShelfFolderLocation({required this.rootId, required this.relativePath});
}

final class ShelfDocumentLocation extends ShelfSourceLocation {
  final DocumentId documentId;

  const ShelfDocumentLocation(this.documentId);

  @override
  String get relativePath => documentId.path;
}

/// Platform capability behind source-oriented shelf context commands.
abstract interface class ShelfSourceActions {
  /// The platform's native name for revealing a filesystem entry.
  String get revealLabel;

  /// Returns a native absolute path when this source has one.
  String? absolutePath(ShelfSourceLocation source);

  /// Selects the source in the native file manager when it is reachable.
  Future<void> reveal(ShelfSourceLocation source);
}
