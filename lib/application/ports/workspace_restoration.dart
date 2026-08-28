import '../../domain/library/library.dart';
import 'workspace_session_repository.dart';

/// Atomically replaces both projections of the currently open reading room.
abstract interface class WorkspaceRestoration {
  Future<void> replace(Library library, WorkspaceSession session);
}
