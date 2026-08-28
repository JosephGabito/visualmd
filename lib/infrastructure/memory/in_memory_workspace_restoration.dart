import '../../application/ports/workspace_restoration.dart';
import '../../application/ports/workspace_session_repository.dart';
import '../../domain/library/library.dart';
import 'in_memory_reader_state.dart';

final class InMemoryWorkspaceRestoration implements WorkspaceRestoration {
  final InMemoryReaderState _state;

  const InMemoryWorkspaceRestoration(this._state);

  @override
  Future<void> replace(Library library, WorkspaceSession session) async {
    _state.replace(library, session);
  }
}
