import '../../application/ports/workspace_session_repository.dart';
import 'in_memory_reader_state.dart';

final class InMemoryWorkspaceSessionRepository
    implements WorkspaceSessionRepository {
  final InMemoryReaderState _state;

  InMemoryWorkspaceSessionRepository([InMemoryReaderState? state])
    : _state = state ?? InMemoryReaderState();

  @override
  Future<WorkspaceSession?> current() async => _state.workspace;

  @override
  Future<void> save(WorkspaceSession session) async =>
      _state.workspace = session;
}
