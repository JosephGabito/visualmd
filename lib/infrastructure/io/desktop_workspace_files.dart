// ignore_for_file: prefer_initializing_formals — the public parameter hides the private field.

import 'dart:io';

import 'package:file_selector/file_selector.dart';

import '../../application/ports/workspace_files.dart';
import 'desktop_atomic_files.dart';
import 'local_folder.dart';

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

  const DesktopWorkspaceFiles({
    DesktopAtomicFiles atomic = const DesktopAtomicFiles(),
    DesktopWorkspaceSaveLocation? saveLocation,
  }) : _atomic = atomic,
       _saveLocation = saveLocation;

  @override
  Future<WorkspaceFileRef?> pickOpen() async {
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
  Future<String> read(WorkspaceFileRef file) => File(file.id).readAsString();

  @override
  Future<void> write(WorkspaceFileRef file, String contents) async {
    await _atomic.writeSelected(target: File(file.id), contents: contents);
  }
}
