// ignore_for_file: prefer_initializing_formals — the public parameter hides the private field.

import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

import '../../application/ports/workspace_files.dart';
import '../opaque_ids.dart';
import 'desktop_atomic_files.dart';
import 'desktop_security_scope.dart';
import 'local_folder.dart';
import 'scoped_access.dart';

const _workspaceTypes = <XTypeGroup>[
  XTypeGroup(
    label: 'Visual MD workspace',
    extensions: ['json'],
    uniformTypeIdentifiers: ['public.json'],
  ),
];

typedef DesktopWorkspaceSaveLocation = Future<String?> Function(
  String suggestedName,
);

/// Native workspace dialogs plus recoverable replacement of existing files.
final class DesktopWorkspaceFiles implements WorkspaceFiles {
  final DesktopAtomicFiles _atomic;
  final DesktopWorkspaceSaveLocation? _saveLocation;
  final ScopedAccess _access;
  final Map<String, ({String path, Uint8List? bookmark})> _opened = {};
  final List<WorkspaceFileRef> _pendingOpens = [];

  DesktopWorkspaceFiles({
    DesktopAtomicFiles atomic = const DesktopAtomicFiles(),
    DesktopWorkspaceSaveLocation? saveLocation,
    ScopedAccess access = const DesktopSecurityScope(),
  }) : _atomic = atomic,
       _saveLocation = saveLocation,
       _access = access;

  /// Retains a Finder-granted file behind a process-local opaque reference.
  WorkspaceFileRef registerOpened(String path, Uint8List? bookmark) {
    final id = OpaqueIds.next('opened-workspace');
    _opened[id] = (path: path, bookmark: bookmark);
    final file = WorkspaceFileRef(id: id, name: baseName(path));
    _pendingOpens.add(file);
    return file;
  }

  @override
  Future<WorkspaceFileRef?> pickOpen() async {
    if (_pendingOpens.isNotEmpty) return _pendingOpens.removeAt(0);
    final selected = await openFile(
      acceptedTypeGroups: _workspaceTypes,
      confirmButtonText: 'Open workspace',
    );
    if (selected == null) return null;
    return WorkspaceFileRef(id: selected.path, name: baseName(selected.path));
  }

  @override
  Future<WorkspaceFileRef?> pickSave({required String suggestedName}) async {
    final selectedPath = _saveLocation == null
        ? (await getSaveLocation(
            acceptedTypeGroups: _workspaceTypes,
            suggestedName: suggestedName,
            confirmButtonText: 'Save workspace',
          ))?.path
        : await _saveLocation(suggestedName);
    if (selectedPath == null) return null;

    // Normalising after selection would point at a different sandbox resource.
    return WorkspaceFileRef(id: selectedPath, name: baseName(selectedPath));
  }

  @override
  Future<String> read(WorkspaceFileRef file) {
    final opened = _opened[file.id];
    final path = opened?.path ?? file.id;
    return _access.within(opened?.bookmark, () => File(path).readAsString());
  }

  @override
  Future<void> write(WorkspaceFileRef file, String contents) async {
    final opened = _opened[file.id];
    final path = opened?.path ?? file.id;
    await _access.within(
      opened?.bookmark,
      () => _atomic.writeSelected(target: File(path), contents: contents),
    );
  }
}
