// ignore_for_file: prefer_initializing_formals — named parameters describe the composition contract.

import '../../domain/library/library.dart';
import '../../domain/workspace/workspace.dart';
import '../../domain/workspace/workspace_theme.dart';
import '../library_mutation_queue.dart';
import '../workspace_autosave.dart';
import '../ports/workspace_restoration.dart';
import '../ports/workspace_ids.dart';
import '../ports/workspace_session_repository.dart';

/// Starts an unbound reading room without writing a file.
final class CreateWorkspace {
  final WorkspaceIds _ids;
  final WorkspaceRestoration _restoration;
  final LibraryMutationQueue _mutations;
  final WorkspaceAutosave _autosave;

  const CreateWorkspace({
    required WorkspaceIds ids,
    required WorkspaceRestoration restoration,
    required LibraryMutationQueue mutations,
    required WorkspaceAutosave autosave,
  }) : _ids = ids,
       _restoration = restoration,
       _mutations = mutations,
       _autosave = autosave;

  Future<WorkspaceSession> execute(WorkspaceTheme theme) async {
    await _autosave.flush();
    return _mutations.run(() async {
      final workspace = Workspace(
        id: _ids.workspaceId(),
        documentRootAbsolutePath: null,
        theme: theme,
      );
      final session = WorkspaceSession(
        workspace: workspace,
        file: null,
        dirty: true,
      );
      _restoration.replace(Library.empty(), session);
      return session;
    });
  }
}
