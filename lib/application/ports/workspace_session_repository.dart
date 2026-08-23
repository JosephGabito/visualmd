import '../../domain/workspace/workspace.dart';
import '../../domain/workspace/workspace_id.dart';
import 'workspace_files.dart';

/// The current durable model and the user-owned file it is bound to.
final class WorkspaceSession {
  final Workspace workspace;
  final WorkspaceFileRef? file;
  final bool dirty;
  final Set<WorkspaceSourceId> unavailableSources;

  WorkspaceSession({
    required this.workspace,
    required this.file,
    required this.dirty,
    Set<WorkspaceSourceId> unavailableSources = const {},
  }) : unavailableSources = Set.unmodifiable(unavailableSources);

  WorkspaceSession copyWith({
    Workspace? workspace,
    WorkspaceFileRef? file,
    bool clearFile = false,
    bool? dirty,
    Set<WorkspaceSourceId>? unavailableSources,
  }) => WorkspaceSession(
    workspace: workspace ?? this.workspace,
    file: clearFile ? null : file ?? this.file,
    dirty: dirty ?? this.dirty,
    unavailableSources: unavailableSources ?? this.unavailableSources,
  );
}

abstract interface class WorkspaceSessionRepository {
  Future<WorkspaceSession?> current();
  Future<void> save(WorkspaceSession session);
}
