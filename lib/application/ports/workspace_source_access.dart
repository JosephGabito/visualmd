import '../../domain/workspace/workspace.dart';
import '../../domain/workspace/workspace_id.dart';
import '../../domain/workspace/workspace_source.dart';
import '../ports/folder_scanner.dart';
import '../ports/markdown_scanner.dart';

/// The path information available when a source is first offered.
final class WorkspaceSourceLocation {
  final String displayName;
  final String? absolutePath;

  const WorkspaceSourceLocation({
    required this.displayName,
    required this.absolutePath,
  });
}

/// Port: bridges durable workspace sources to fresh platform handles.
abstract interface class WorkspaceSourceAccess {
  Future<WorkspaceSourceLocation> locateFolder(FolderRef ref);
  Future<WorkspaceSourceLocation> locateMarkdown(MarkdownRef ref);

  Future<void> bindFolder(
    WorkspaceId workspaceId,
    WorkspaceSourceId sourceId,
    FolderRef ref,
  );

  Future<void> bindMarkdown(
    WorkspaceId workspaceId,
    WorkspaceSourceId sourceId,
    MarkdownRef ref,
  );

  /// Carries machine-local grants forward when Save As forks workspace identity.
  Future<void> forkBindings(
    WorkspaceId from,
    WorkspaceId to,
    Iterable<WorkspaceSourceId> sources,
  );

  Future<FolderRef> restoreFolder(Workspace workspace, WorkspaceSource source);

  Future<MarkdownRef> restoreMarkdown(
    Workspace workspace,
    WorkspaceSource source,
  );

  Future<FolderRef?> reconnectFolder(
    Workspace workspace,
    WorkspaceSource source,
  );

  Future<MarkdownRef?> reconnectMarkdown(
    Workspace workspace,
    WorkspaceSource source,
  );
}

/// The source is remembered but cannot currently be reached on this machine.
final class WorkspaceSourceUnavailable implements Exception {
  final WorkspaceSource source;

  const WorkspaceSourceUnavailable(this.source);
}
