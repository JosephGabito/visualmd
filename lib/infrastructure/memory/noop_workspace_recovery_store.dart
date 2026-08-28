import '../../application/ports/workspace_recovery_store.dart';
import '../../domain/workspace/workspace.dart';

/// Platforms without private filesystem recovery start with an empty room.
final class NoopWorkspaceRecoveryStore implements WorkspaceRecoveryStore {
  const NoopWorkspaceRecoveryStore();

  @override
  Future<Workspace?> load() async => null;

  @override
  Future<void> save(Workspace workspace) async {}
}
