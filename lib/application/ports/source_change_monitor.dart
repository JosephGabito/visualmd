import 'folder_scanner.dart';
import 'markdown_scanner.dart';

/// An operating-system or browser signal that source bytes may have changed.
///
/// These are invalidations, not file contents. The application always rereads
/// after the quiet period, so delayed or out-of-order platform events cannot
/// overwrite a newer save with stale bytes carried by an older event.
sealed class SourceChange {
  const SourceChange();
}

final class FolderDocumentsInvalidated extends SourceChange {
  final FolderRef folder;
  final Set<String> relativePaths;

  FolderDocumentsInvalidated(this.folder, Iterable<String> relativePaths)
    : relativePaths = Set.unmodifiable(relativePaths);
}

/// The platform could identify the root but not the individual Markdown path.
/// Directory creation, removal, and coalesced watcher events use this route.
final class FolderRescanRequested extends SourceChange {
  final FolderRef folder;
  const FolderRescanRequested(this.folder);
}

final class MarkdownInvalidated extends SourceChange {
  final MarkdownRef markdown;
  const MarkdownInvalidated(this.markdown);
}

/// Watching failed, but the monitor may continue through a slower fallback.
final class SourceWatchFailed extends SourceChange {
  final String sourceName;
  final String reason;

  const SourceWatchFailed(this.sourceName, this.reason);
}

/// Supplies invalidation streams for sources the reader already owns.
abstract interface class SourceChangeMonitor {
  Stream<SourceChange> watchFolder(FolderRef folder);
  Stream<SourceChange> watchMarkdown(MarkdownRef markdown);
}
