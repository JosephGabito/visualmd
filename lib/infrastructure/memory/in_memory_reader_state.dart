import '../../application/ports/workspace_session_repository.dart';
import '../../domain/library/library.dart';

/// Shared storage behind the two repositories and atomic workspace restore.
final class InMemoryReaderState {
  Library? library;
  WorkspaceSession? workspace;

  void replace(Library nextLibrary, WorkspaceSession nextWorkspace) {
    library = nextLibrary;
    workspace = nextWorkspace;
  }
}
