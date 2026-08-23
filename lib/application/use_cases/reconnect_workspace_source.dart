import '../../domain/workspace/workspace_id.dart';
import '../../domain/workspace/workspace_source.dart';
import '../ports/folder_scanner.dart';
import '../ports/markdown_scanner.dart';
import '../ports/workspace_session_repository.dart';
import '../ports/workspace_source_access.dart';

sealed class ReconnectedWorkspaceSource {
  const ReconnectedWorkspaceSource();
}

final class ReconnectedFolder extends ReconnectedWorkspaceSource {
  final FolderRef ref;
  final int insertionIndex;
  const ReconnectedFolder(this.ref, this.insertionIndex);
}

final class ReconnectedMarkdown extends ReconnectedWorkspaceSource {
  final MarkdownRef ref;
  final int insertionIndex;
  const ReconnectedMarkdown(this.ref, this.insertionIndex);
}

/// Lets the reader grant a remembered but unavailable source new access.
final class ReconnectWorkspaceSource {
  final WorkspaceSessionRepository _sessions;
  final WorkspaceSourceAccess _access;

  const ReconnectWorkspaceSource({
    required WorkspaceSessionRepository sessions,
    required WorkspaceSourceAccess access,
  }) : _sessions = sessions,
       _access = access;

  Future<ReconnectedWorkspaceSource?> execute(WorkspaceSourceId id) async {
    final session = await _sessions.current();
    if (session == null || !session.unavailableSources.contains(id)) {
      return null;
    }
    final workspace = session.workspace;
    final source = workspace.sourceById(id);
    if (source == null) return null;
    if (workspace.folders.any((candidate) => candidate.id == id)) {
      final ref = await _access.reconnectFolder(workspace, source);
      if (ref == null) return null;
      return ReconnectedFolder(
        ref,
        _availableIndex(workspace.folders, id, session.unavailableSources),
      );
    }
    final ref = await _access.reconnectMarkdown(workspace, source);
    if (ref == null) return null;
    return ReconnectedMarkdown(
      ref,
      _availableIndex(workspace.markdowns, id, session.unavailableSources),
    );
  }
}

int _availableIndex(
  Iterable<WorkspaceSource> sources,
  WorkspaceSourceId target,
  Set<WorkspaceSourceId> unavailable,
) {
  var index = 0;
  for (final source in sources) {
    if (source.id == target) return index;
    if (!unavailable.contains(source.id)) index++;
  }
  return index;
}
// ignore_for_file: prefer_initializing_formals — named parameters describe the composition contract.
