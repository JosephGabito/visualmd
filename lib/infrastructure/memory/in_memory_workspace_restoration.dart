import '../../application/ports/workspace_restoration.dart';
import '../../application/ports/workspace_session_repository.dart';
import '../../domain/library/library.dart';
import 'in_memory_reader_state.dart';

final class InMemoryWorkspaceRestoration implements WorkspaceRestoration {
  final InMemoryReaderState _state;

  const InMemoryWorkspaceRestoration(this._state);

  @override
  void replace(Library library, WorkspaceSession session) {
    _state.replace(library, session);
  }
}
