import 'package:web/web.dart' as web;

import '../../application/ports/folder_scanner.dart';
import '../../application/ports/markdown_scanner.dart';
import '../../application/ports/workspace_source_access.dart';
import '../../domain/workspace/workspace.dart';
import '../../domain/workspace/workspace_id.dart';
import '../../domain/workspace/workspace_source.dart';
import 'browser_file_system_access.dart';
import 'browser_folder.dart';
import 'browser_handle_store.dart';
import 'browser_markdown.dart';
import 'browser_folder_picker.dart';
import 'browser_markdown_picker.dart';

/// Persists modern browser handles and requests permission when restoring.
final class BrowserWorkspaceSourceAccess implements WorkspaceSourceAccess {
  final BrowserFolderRegistry _folders;
  final BrowserMarkdownRegistry _markdowns;
  final BrowserHandleStore _handles;

  const BrowserWorkspaceSourceAccess(
    this._folders,
    this._markdowns,
    this._handles,
  );

  @override
  Future<WorkspaceSourceLocation> locateFolder(FolderRef ref) async {
    final folder = _folders.lookup(ref);
    if (folder == null) throw FolderUnavailable(ref);
    return WorkspaceSourceLocation(
      displayName: folder.name,
      absolutePath: null,
    );
  }

  @override
  Future<WorkspaceSourceLocation> locateMarkdown(MarkdownRef ref) async {
    final markdown = _markdowns.lookup(ref);
    if (markdown == null) throw MarkdownUnavailable(ref);
    return WorkspaceSourceLocation(
      displayName: markdown.name,
      absolutePath: null,
    );
  }

  @override
  Future<void> bindFolder(
    WorkspaceId workspaceId,
    WorkspaceSourceId sourceId,
    FolderRef ref,
  ) async {
    final folder = _folders.lookup(ref);
    if (folder is HandleDirectory) {
      await _handles.put(_key(workspaceId, sourceId), folder.handle);
    }
  }

  @override
  Future<void> bindMarkdown(
    WorkspaceId workspaceId,
    WorkspaceSourceId sourceId,
    MarkdownRef ref,
  ) async {
    final markdown = _markdowns.lookup(ref);
    if (markdown is BrowserMarkdownHandle) {
      await _handles.put(_key(workspaceId, sourceId), markdown.handle);
    }
  }

  @override
  Future<void> forkBindings(
    WorkspaceId from,
    WorkspaceId to,
    Iterable<WorkspaceSourceId> sources,
  ) async {
    for (final source in sources) {
      await _handles.copy(_key(from, source), _key(to, source));
    }
  }

  @override
  Future<FolderRef> restoreFolder(
    Workspace workspace,
    WorkspaceSource source,
  ) async {
    final existing = FolderRef(id: source.id.value, name: source.displayName);
    if (_folders.lookup(existing) != null) return existing;
    final web.FileSystemHandle? handle;
    try {
      handle = await _handles.get(_key(workspace.id, source.id));
    } on StateError {
      throw WorkspaceSourceUnavailable(source);
    }
    if (handle == null ||
        handle.kind != 'directory' ||
        !await ensureReadPermission(handle)) {
      throw WorkspaceSourceUnavailable(source);
    }
    final directory = handle as web.FileSystemDirectoryHandle;
    return _folders.register(
      source.displayName,
      HandleDirectory(directory),
      preferredId: source.id.value,
    );
  }

  @override
  Future<MarkdownRef> restoreMarkdown(
    Workspace workspace,
    WorkspaceSource source,
  ) async {
    final existing = MarkdownRef(id: source.id.value, name: source.displayName);
    if (_markdowns.lookup(existing) != null) return existing;
    final web.FileSystemHandle? handle;
    try {
      handle = await _handles.get(_key(workspace.id, source.id));
    } on StateError {
      throw WorkspaceSourceUnavailable(source);
    }
    if (handle == null ||
        handle.kind != 'file' ||
        !await ensureReadPermission(handle)) {
      throw WorkspaceSourceUnavailable(source);
    }
    final file = handle as web.FileSystemFileHandle;
    return _markdowns.register(
      source.displayName,
      BrowserMarkdownHandle(file),
      preferredId: source.id.value,
    );
  }

  @override
  Future<FolderRef?> reconnectFolder(
    Workspace workspace,
    WorkspaceSource source,
  ) async {
    final offered = await BrowserFolderPicker(_folders).pick();
    if (offered == null) return null;
    final folder = _folders.lookup(offered);
    if (folder == null) return null;
    final stable = _folders.register(
      source.displayName,
      folder,
      preferredId: source.id.value,
    );
    await bindFolder(workspace.id, source.id, stable);
    return stable;
  }

  @override
  Future<MarkdownRef?> reconnectMarkdown(
    Workspace workspace,
    WorkspaceSource source,
  ) async {
    final offered = await BrowserMarkdownPicker(_markdowns).pick();
    if (offered == null) return null;
    final markdown = _markdowns.lookup(offered);
    if (markdown == null) return null;
    final stable = _markdowns.register(
      source.displayName,
      markdown,
      preferredId: source.id.value,
    );
    await bindMarkdown(workspace.id, source.id, stable);
    return stable;
  }
}

String _key(WorkspaceId workspaceId, WorkspaceSourceId sourceId) =>
    '${workspaceId.value}/${sourceId.value}';
