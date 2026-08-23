import 'dart:io';
import 'dart:typed_data';

import '../../application/ports/folder_scanner.dart';
import '../../application/ports/markdown_scanner.dart';
import '../../application/ports/workspace_source_access.dart';
import '../../domain/workspace/workspace.dart';
import '../../domain/workspace/workspace_id.dart';
import '../../domain/workspace/workspace_source.dart';
import 'desktop_bookmarks.dart';
import 'desktop_folder_picker.dart';
import 'desktop_markdown_picker.dart';
import 'local_folder.dart';
import 'local_markdown.dart';
import 'reader_files.dart';

/// Restores workspace paths and their machine-local macOS access grants.
final class DesktopWorkspaceSourceAccess implements WorkspaceSourceAccess {
  final LocalFolderRegistry _folders;
  final LocalMarkdownRegistry _markdowns;
  final ReaderFiles _files;

  const DesktopWorkspaceSourceAccess(
    this._folders,
    this._markdowns,
    this._files,
  );

  @override
  Future<WorkspaceSourceLocation> locateFolder(FolderRef ref) async {
    final folder = _folders.lookup(ref);
    if (folder is! LocalDirectory) {
      throw StateError('Only directories can be saved as workspace folders.');
    }
    return WorkspaceSourceLocation(
      displayName: folder.name,
      absolutePath: File(folder.path).absolute.path,
    );
  }

  @override
  Future<WorkspaceSourceLocation> locateMarkdown(MarkdownRef ref) async {
    final markdown = _markdowns.lookup(ref);
    if (markdown == null) throw MarkdownUnavailable(ref);
    return WorkspaceSourceLocation(
      displayName: baseName(markdown.path),
      absolutePath: File(markdown.path).absolute.path,
    );
  }

  @override
  Future<void> bindFolder(
    WorkspaceId workspaceId,
    WorkspaceSourceId sourceId,
    FolderRef ref,
  ) async {
    final folder = _folders.lookup(ref);
    if (folder is! LocalDirectory) return;
    await _remember(workspaceId, sourceId, folder.path, folder.bookmark);
  }

  @override
  Future<void> bindMarkdown(
    WorkspaceId workspaceId,
    WorkspaceSourceId sourceId,
    MarkdownRef ref,
  ) async {
    final markdown = _markdowns.lookup(ref);
    if (markdown == null) return;
    await _remember(workspaceId, sourceId, markdown.path, markdown.bookmark);
  }

  @override
  Future<void> forkBindings(
    WorkspaceId from,
    WorkspaceId to,
    Iterable<WorkspaceSourceId> sources,
  ) => _files.forkWorkspaceAccess(
    from.value,
    to.value,
    sources.map((source) => source.value),
  );

  Future<void> _remember(
    WorkspaceId workspaceId,
    WorkspaceSourceId sourceId,
    String path,
    Uint8List? bookmark,
  ) async {
    final durable = bookmark ?? await DesktopBookmarks.create(path);
    await _files.writeWorkspaceAccess(
      workspaceId.value,
      sourceId.value,
      path: path,
      bookmark: durable,
    );
  }

  @override
  Future<FolderRef> restoreFolder(
    Workspace workspace,
    WorkspaceSource source,
  ) async {
    final stored = await _files.readWorkspaceAccess(
      workspace.id.value,
      source.id.value,
    );
    final restored = await _resolveStored(workspace, source, stored);
    final path = restored.path;
    if (!await Directory(path).exists()) {
      throw WorkspaceSourceUnavailable(source);
    }
    final folder = LocalDirectory(path, bookmark: restored.bookmark);
    return _folders.register(
      source.displayName,
      folder,
      identity: localFolderIdentity(path),
      preferredId: source.id.value,
    );
  }

  @override
  Future<MarkdownRef> restoreMarkdown(
    Workspace workspace,
    WorkspaceSource source,
  ) async {
    final stored = await _files.readWorkspaceAccess(
      workspace.id.value,
      source.id.value,
    );
    final restored = await _resolveStored(workspace, source, stored);
    final path = restored.path;
    if (!await File(path).exists()) throw WorkspaceSourceUnavailable(source);
    final markdown = LocalMarkdown(path, bookmark: restored.bookmark);
    return _markdowns.register(
      source.displayName,
      markdown,
      identity: localMarkdownIdentity(path),
      preferredId: source.id.value,
    );
  }

  @override
  Future<FolderRef?> reconnectFolder(
    Workspace workspace,
    WorkspaceSource source,
  ) async {
    final offered = await DesktopFolderPicker(_folders).pick();
    if (offered == null) return null;
    final folder = _folders.lookup(offered);
    if (folder == null) return null;
    final stable = _folders.register(
      source.displayName,
      folder,
      identity: folder is LocalDirectory
          ? localFolderIdentity(folder.path)
          : null,
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
    final offered = await DesktopMarkdownPicker(_markdowns).pick();
    if (offered == null) return null;
    final markdown = _markdowns.lookup(offered);
    if (markdown == null) return null;
    final stable = _markdowns.register(
      source.displayName,
      markdown,
      identity: localMarkdownIdentity(markdown.path),
      preferredId: source.id.value,
    );
    await bindMarkdown(workspace.id, source.id, stable);
    return stable;
  }

  Future<({String path, Uint8List? bookmark})> _resolveStored(
    Workspace workspace,
    WorkspaceSource source,
    ({String path, Uint8List? bookmark})? stored,
  ) async {
    final bookmark = stored?.bookmark;
    if (bookmark != null && Platform.isMacOS) {
      final resolution = await DesktopBookmarks.resolve(bookmark);
      if (resolution != null) {
        if (resolution.refreshed || resolution.path != stored!.path) {
          await _files.writeWorkspaceAccess(
            workspace.id.value,
            source.id.value,
            path: resolution.path,
            bookmark: resolution.bookmark,
          );
        }
        return (path: resolution.path, bookmark: resolution.bookmark);
      }
    }
    return (path: _resolve(workspace, source), bookmark: bookmark);
  }
}

String _resolve(Workspace workspace, WorkspaceSource source) {
  final root = workspace.documentRootAbsolutePath;
  if (root == null) throw WorkspaceSourceUnavailable(source);
  if (source.relativePath == '.') return root;
  return '$root${Platform.pathSeparator}${source.relativePath.replaceAll('/', Platform.pathSeparator)}';
}
