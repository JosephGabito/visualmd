import '../application/ports/folder_scanner.dart';
import '../application/ports/markdown_scanner.dart';
import '../application/ports/workspace_source_access.dart';
import '../domain/workspace/workspace.dart';
import '../domain/workspace/workspace_id.dart';
import '../domain/workspace/workspace_source.dart';
import 'memory/sample_folder_scanner.dart';

/// Keeps the bundled sample restorable while routing real sources by platform.
final class RoutingWorkspaceSourceAccess implements WorkspaceSourceAccess {
  final WorkspaceSourceAccess _platform;

  const RoutingWorkspaceSourceAccess(this._platform);

  @override
  Future<WorkspaceSourceLocation> locateFolder(FolderRef ref) async =>
      ref.id == SampleFolderScanner.ref.id
      ? const WorkspaceSourceLocation(
          displayName: 'Welcome',
          absolutePath: null,
        )
      : _platform.locateFolder(ref);

  @override
  Future<WorkspaceSourceLocation> locateMarkdown(MarkdownRef ref) =>
      _platform.locateMarkdown(ref);

  @override
  Future<void> bindFolder(
    WorkspaceId workspaceId,
    WorkspaceSourceId sourceId,
    FolderRef ref,
  ) => ref.id == SampleFolderScanner.ref.id
      ? Future.value()
      : _platform.bindFolder(workspaceId, sourceId, ref);

  @override
  Future<void> bindMarkdown(
    WorkspaceId workspaceId,
    WorkspaceSourceId sourceId,
    MarkdownRef ref,
  ) => _platform.bindMarkdown(workspaceId, sourceId, ref);

  @override
  Future<void> forkBindings(
    WorkspaceId from,
    WorkspaceId to,
    Iterable<WorkspaceSourceId> sources,
  ) => _platform.forkBindings(from, to, sources);

  @override
  Future<FolderRef> restoreFolder(
    Workspace workspace,
    WorkspaceSource source,
  ) async => source.id.value == SampleFolderScanner.ref.id
      ? SampleFolderScanner.ref
      : _platform.restoreFolder(workspace, source);

  @override
  Future<MarkdownRef> restoreMarkdown(
    Workspace workspace,
    WorkspaceSource source,
  ) => _platform.restoreMarkdown(workspace, source);

  @override
  Future<FolderRef?> reconnectFolder(
    Workspace workspace,
    WorkspaceSource source,
  ) => _platform.reconnectFolder(workspace, source);

  @override
  Future<MarkdownRef?> reconnectMarkdown(
    Workspace workspace,
    WorkspaceSource source,
  ) => _platform.reconnectMarkdown(workspace, source);
}
