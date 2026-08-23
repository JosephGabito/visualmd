// ignore_for_file: prefer_initializing_formals — named parameters describe the composition contract.

import '../library_mutation_queue.dart';
import '../workspace_autosave.dart';
import '../ports/workspace_codec.dart';
import '../ports/workspace_files.dart';
import '../ports/workspace_ids.dart';
import '../ports/workspace_session_repository.dart';
import '../ports/workspace_source_access.dart';

/// Flushes the current workspace, asking for a file the first time.
final class SaveWorkspace {
  final WorkspaceSessionRepository _sessions;
  final WorkspaceFiles _files;
  final WorkspaceCodec _codec;
  final LibraryMutationQueue _mutations;
  final WorkspaceAutosave _autosave;

  const SaveWorkspace({
    required WorkspaceSessionRepository sessions,
    required WorkspaceFiles files,
    required WorkspaceCodec codec,
    required LibraryMutationQueue mutations,
    required WorkspaceAutosave autosave,
  }) : _sessions = sessions,
       _files = files,
       _codec = codec,
       _mutations = mutations,
       _autosave = autosave;

  Future<WorkspaceSession?> execute() async {
    await _autosave.flush();
    return _mutations.run(() async {
      final current = await _sessions.current();
      if (current == null) return null;
      if (current.file != null && !current.dirty) return current;
      final file =
          current.file ??
          await _files.pickSave(
            suggestedName: 'Untitled.visualmd-workspace.json',
          );
      if (file == null) return current;
      await _files.write(file, _codec.encode(current.workspace));
      final saved = current.copyWith(file: file, dirty: false);
      await _sessions.save(saved);
      return saved;
    });
  }
}

/// Forks the reading room into a newly selected workspace file.
final class SaveWorkspaceAs {
  final WorkspaceSessionRepository _sessions;
  final WorkspaceFiles _files;
  final WorkspaceCodec _codec;
  final WorkspaceIds _ids;
  final LibraryMutationQueue _mutations;
  final WorkspaceSourceAccess _access;
  final WorkspaceAutosave _autosave;

  const SaveWorkspaceAs({
    required WorkspaceSessionRepository sessions,
    required WorkspaceFiles files,
    required WorkspaceCodec codec,
    required WorkspaceIds ids,
    required LibraryMutationQueue mutations,
    required WorkspaceSourceAccess access,
    required WorkspaceAutosave autosave,
  }) : _sessions = sessions,
       _files = files,
       _codec = codec,
       _ids = ids,
       _mutations = mutations,
       _access = access,
       _autosave = autosave;

  Future<WorkspaceSession?> execute() async {
    _autosave.cancel();
    return _mutations.run(() async {
      final current = await _sessions.current();
      if (current == null) return null;
      var completed = false;
      try {
        final file = await _files.pickSave(
          suggestedName: workspaceFileName(current.file?.name ?? 'Untitled'),
        );
        if (file == null) return current;
        final fork = current.workspace.copyWith(id: _ids.workspaceId());
        await _access.forkBindings(
          current.workspace.id,
          fork.id,
          fork.sources.map((source) => source.id),
        );
        await _files.write(file, _codec.encode(fork));
        final saved = current.copyWith(
          workspace: fork,
          file: file,
          dirty: false,
        );
        await _sessions.save(saved);
        completed = true;
        return saved;
      } finally {
        // Save As temporarily owns the write queue. If it is cancelled or
        // fails, the old bound workspace must resume its deferred save rather
        // than becoming silently dirty forever.
        if (!completed &&
            current.dirty &&
            current.file?.supportsAutomaticWrites == true) {
          _autosave.schedule();
        }
      }
    });
  }
}
