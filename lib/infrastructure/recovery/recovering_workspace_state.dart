import '../../application/ports/workspace_recovery_store.dart';
import '../../application/ports/workspace_restoration.dart';
import '../../application/ports/workspace_session_repository.dart';
import '../../domain/library/library.dart';

/// Adds private crash/relaunch recovery without making journal availability a
/// condition of committing the live reading room.
final class RecoveringWorkspaceSessionRepository
    implements WorkspaceSessionRepository {
  final WorkspaceSessionRepository _memory;
  final WorkspaceRecoveryStore _recovery;

  const RecoveringWorkspaceSessionRepository(this._memory, this._recovery);

  @override
  Future<WorkspaceSession?> current() => _memory.current();

  @override
  Future<void> save(WorkspaceSession session) async {
    await _memory.save(session);
    await _remember(session);
  }

  Future<void> _remember(WorkspaceSession session) async {
    try {
      await _recovery.save(session.workspace);
    } on Object {
      // Recovery is a second line of defence. A private journal failure must
      // never undo a reading-room change that already succeeded in memory.
    }
  }
}

/// Journals the atomic Library/Workspace replacement path used by opening and
/// creating a reading room. Ordinary mutations use the repository above.
final class RecoveringWorkspaceRestoration implements WorkspaceRestoration {
  final WorkspaceRestoration _memory;
  final WorkspaceRecoveryStore _recovery;

  const RecoveringWorkspaceRestoration(this._memory, this._recovery);

  @override
  Future<void> replace(Library library, WorkspaceSession session) async {
    await _memory.replace(library, session);
    try {
      await _recovery.save(session.workspace);
    } on Object {
      // The live projections are authoritative for this run. See the matching
      // repository adapter for why recovery remains best-effort.
    }
  }
}
