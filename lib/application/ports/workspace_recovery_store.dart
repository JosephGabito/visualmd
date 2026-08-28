import '../../domain/workspace/workspace.dart';

/// Machine-local recovery for the last reading room.
///
/// This is deliberately separate from [WorkspaceFiles]: recovery is private
/// application state, never a user-owned workspace document or file binding.
abstract interface class WorkspaceRecoveryStore {
  Future<Workspace?> load();
  Future<void> save(Workspace workspace);
}
