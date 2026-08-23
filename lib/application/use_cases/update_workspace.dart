// ignore_for_file: prefer_initializing_formals — named parameters describe the composition contract.

import '../../domain/library/document_id.dart';
import '../../domain/library/library.dart';
import '../../domain/workspace/workspace.dart';
import '../../domain/workspace/workspace_id.dart';
import '../../domain/workspace/workspace_source.dart';
import '../../domain/workspace/workspace_theme.dart';
import '../library_mutation_queue.dart';
import '../workspace_autosave.dart';
import '../ports/folder_scanner.dart';
import '../ports/markdown_scanner.dart';
import '../ports/workspace_codec.dart';
import '../ports/workspace_files.dart';
import '../ports/workspace_mutation_committer.dart';
import '../ports/workspace_session_repository.dart';
import '../ports/workspace_source_access.dart';

/// Keeps workspace intent in step with successful in-memory library changes.
final class UpdateWorkspace implements WorkspaceMutationCommitter {
  final WorkspaceSessionRepository _sessions;
  final WorkspaceSourceAccess _access;
  final WorkspaceFiles _files;
  final WorkspaceCodec _codec;
  final LibraryMutationQueue _mutations;
  final WorkspaceAutosave _autosave;

  const UpdateWorkspace({
    required WorkspaceSessionRepository sessions,
    required WorkspaceSourceAccess access,
    required WorkspaceFiles files,
    required WorkspaceCodec codec,
    required LibraryMutationQueue mutations,
    required WorkspaceAutosave autosave,
  }) : _sessions = sessions,
       _access = access,
       _files = files,
       _codec = codec,
       _mutations = mutations,
       _autosave = autosave;

  @override
  Future<void> folderAdded(
    FolderRef ref,
    Library library,
    DocumentId? active,
  ) async {
    var current = await _sessions.current();
    if (current == null) return;
    final location = await _access.locateFolder(ref);
    final source = WorkspaceSource(
      id: WorkspaceSourceId(ref.id),
      displayName: location.displayName,
      relativePath: '.',
    );
    await _access.bindFolder(current.workspace.id, source.id, ref);
    current = current.copyWith(
      unavailableSources: {...current.unavailableSources}..remove(source.id),
    );
    var workspace = _addLocated(
      current.workspace,
      source,
      location.absolutePath,
    );
    workspace = _synchronize(workspace, library, active);
    await _persist(current, workspace);
  }

  @override
  Future<void> markdownAdded(
    MarkdownRef ref,
    Library library,
    DocumentId active, {
    required bool added,
  }) async {
    var current = await _sessions.current();
    if (current == null) return;
    var workspace = current.workspace;
    if (added) {
      final location = await _access.locateMarkdown(ref);
      final source = WorkspaceSource(
        id: WorkspaceSourceId(ref.id),
        displayName: location.displayName,
        relativePath: '.',
      );
      await _access.bindMarkdown(current.workspace.id, source.id, ref);
      current = current.copyWith(
        unavailableSources: {...current.unavailableSources}..remove(source.id),
      );
      workspace = _addLocated(
        workspace,
        source,
        location.absolutePath,
        markdown: true,
      );
    }
    workspace = _synchronize(workspace, library, active);
    await _persist(current, workspace);
  }

  @override
  Future<void> libraryChanged(Library library, DocumentId? active) async {
    final current = await _sessions.current();
    if (current == null) return;
    await _persist(current, _synchronize(current.workspace, library, active));
  }

  Future<WorkspaceSession?> rememberActive(
    Library library,
    DocumentId? active,
  ) => _mutations.run(() async {
    final current = await _sessions.current();
    if (current == null) return null;
    return _persist(
      current,
      _synchronize(current.workspace, library, active),
      deferred: true,
    );
  });

  Future<WorkspaceSession?> chooseTheme(WorkspaceTheme theme) =>
      _mutations.run(() async {
        final current = await _sessions.current();
        if (current == null) return null;
        return _persist(
          current,
          current.workspace.copyWith(theme: theme),
          deferred: true,
        );
      });

  Future<WorkspaceSession?> removeUnavailable(WorkspaceSourceId id) =>
      _mutations.run(() async {
        final current = await _sessions.current();
        if (current == null || !current.unavailableSources.contains(id)) {
          return current;
        }
        final workspace = current.workspace.copyWith(
          folders: current.workspace.folders.where((source) => source.id != id),
          markdowns: current.workspace.markdowns.where(
            (source) => source.id != id,
          ),
          clearActiveDocument: current.workspace.activeDocument?.sourceId == id,
        );
        final next = current.copyWith(
          unavailableSources: {...current.unavailableSources}..remove(id),
        );
        return _persist(next, workspace);
      });

  Workspace _synchronize(
    Workspace workspace,
    Library library,
    DocumentId? active,
  ) {
    final foldersById = {
      for (final source in workspace.folders) source.id: source,
    };
    final markdownsById = {
      for (final source in workspace.markdowns) source.id: source,
    };
    final folders = <WorkspaceSource>[
      for (final root in library.roots)
        ?foldersById[WorkspaceSourceId(root.id.value)],
    ];
    final markdowns = <WorkspaceSource>[
      for (final document in library.markdowns)
        ?markdownsById[_workspaceSourceId(document.id)],
    ];
    return workspace.copyWith(
      folders: folders,
      markdowns: markdowns,
      activeDocument: active == null ? null : _workspaceDocument(active),
      clearActiveDocument: active == null,
    );
  }

  Future<WorkspaceSession> _persist(
    WorkspaceSession current,
    Workspace projected, {
    bool deferred = false,
  }) async {
    final unavailable = current.unavailableSources;
    if (unavailable.isNotEmpty) {
      projected = projected.copyWith(
        folders: _mergeUnavailable(
          current.workspace.folders,
          projected.folders,
          unavailable,
        ),
        markdowns: _mergeUnavailable(
          current.workspace.markdowns,
          projected.markdowns,
          unavailable,
        ),
      );
    }
    final file = current.file;
    if (deferred) {
      final next = current.copyWith(workspace: projected, dirty: true);
      await _sessions.save(next);
      if (file?.supportsAutomaticWrites ?? false) _autosave.schedule();
      return next;
    }
    _autosave.cancel();
    if (file != null && file.supportsAutomaticWrites) {
      await _files.write(file, _codec.encode(projected));
    }
    final next = current.copyWith(
      workspace: projected,
      dirty: file == null || !file.supportsAutomaticWrites,
    );
    await _sessions.save(next);
    return next;
  }
}

List<WorkspaceSource> _mergeUnavailable(
  List<WorkspaceSource> previous,
  List<WorkspaceSource> available,
  Set<WorkspaceSourceId> unavailable,
) {
  final remaining = [...available];
  final merged = <WorkspaceSource>[];
  for (final source in previous) {
    if (unavailable.contains(source.id)) {
      merged.add(source);
    } else if (remaining.isNotEmpty) {
      merged.add(remaining.removeAt(0));
    }
  }
  return [...merged, ...remaining];
}

Workspace _addLocated(
  Workspace workspace,
  WorkspaceSource source,
  String? absolutePath, {
  bool markdown = false,
}) {
  final normalized = absolutePath == null
      ? null
      : _normalizeAbsolute(absolutePath);
  var root = workspace.documentRootAbsolutePath;
  var markdowns = [...workspace.markdowns];
  var folders = [...workspace.folders];

  if (normalized != null) {
    final parent = _parent(normalized);
    final nextRoot = root == null ? parent : _commonRoot(root, normalized);
    if (nextRoot == null) {
      throw StateError('A workspace cannot span different filesystem volumes.');
    }
    if (root != null && nextRoot != root) {
      markdowns = [
        for (final existing in markdowns)
          existing.copyWith(
            relativePath: _relative(
              nextRoot,
              _resolve(root, existing.relativePath),
            ),
          ),
      ];
      folders = [
        for (final existing in folders)
          existing.copyWith(
            relativePath: _relative(
              nextRoot,
              _resolve(root, existing.relativePath),
            ),
          ),
      ];
    }
    root = nextRoot;
    source = source.copyWith(relativePath: _relative(root, normalized));
  } else {
    source = source.copyWith(relativePath: source.displayName);
  }

  if (markdown) {
    markdowns.removeWhere((candidate) => candidate.id == source.id);
    markdowns.add(source);
  } else {
    folders.removeWhere((candidate) => candidate.id == source.id);
    folders.add(source);
  }
  return Workspace(
    id: workspace.id,
    documentRootAbsolutePath: root,
    theme: workspace.theme,
    markdowns: markdowns,
    folders: folders,
    activeDocument: workspace.activeDocument,
  );
}

WorkspaceSourceId _workspaceSourceId(DocumentId id) {
  const prefix = 'standalone-markdown:';
  final value = id.rootId.value;
  return WorkspaceSourceId(
    value.startsWith(prefix) ? value.substring(prefix.length) : value,
  );
}

WorkspaceDocument _workspaceDocument(DocumentId id) =>
    WorkspaceDocument(sourceId: _workspaceSourceId(id), relativePath: id.path);

String _normalizeAbsolute(String path) {
  final portable = path.replaceAll(r'\', '/');
  final normalized =
      portable == '/' || RegExp(r'^[A-Za-z]:/$').hasMatch(portable)
      ? portable
      : portable.replaceAll(RegExp(r'/+$'), '');
  return normalized.isEmpty ? '/' : normalized;
}

String _parent(String path) {
  final slash = path.lastIndexOf('/');
  if (slash == 2 && RegExp(r'^[A-Za-z]:/').hasMatch(path)) {
    return path.substring(0, 3);
  }
  if (slash <= 0) return path.substring(0, slash + 1);
  return path.substring(0, slash);
}

String? _commonRoot(String left, String right) {
  final a = _normalizeAbsolute(left);
  final b = _normalizeAbsolute(right);
  final aDrive = RegExp(r'^[A-Za-z]:').stringMatch(a)?.toLowerCase();
  final bDrive = RegExp(r'^[A-Za-z]:').stringMatch(b)?.toLowerCase();
  if (aDrive != bDrive) return null;
  final aParts = a.split('/');
  final bParts = b.split('/');
  final shared = <String>[];
  for (var index = 0; index < aParts.length && index < bParts.length; index++) {
    final same = aDrive == null
        ? aParts[index] == bParts[index]
        : aParts[index].toLowerCase() == bParts[index].toLowerCase();
    if (!same) break;
    shared.add(aParts[index]);
  }
  if (shared.isEmpty) return null;
  if (aDrive != null && shared.length == 1) return '${shared.single}/';
  final joined = shared.join('/');
  return joined.isEmpty ? '/' : joined;
}

String _resolve(String root, String relative) =>
    relative == '.' ? root : '${root.replaceAll(RegExp(r'/+$'), '')}/$relative';

String _relative(String root, String absolute) {
  if (root == absolute) return '.';
  final prefix = '${root.replaceAll(RegExp(r'/+$'), '')}/';
  final beneath = RegExp(r'^[A-Za-z]:/').hasMatch(prefix)
      ? absolute.toLowerCase().startsWith(prefix.toLowerCase())
      : absolute.startsWith(prefix);
  if (!beneath) {
    throw StateError('$absolute is not beneath $root.');
  }
  return absolute.substring(prefix.length);
}
