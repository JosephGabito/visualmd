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

/// Native workspace dialogs plus recoverable replacement of existing files.
final class DesktopWorkspaceFiles implements WorkspaceFiles {
  final DesktopAtomicFiles _atomic;

  const DesktopWorkspaceFiles({
    DesktopAtomicFiles atomic = const DesktopAtomicFiles(),
  }) : _atomic = atomic;

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
    final selected = await getSaveLocation(
      acceptedTypeGroups: _workspaceTypes,
      suggestedName: suggestedName,
      confirmButtonText: 'Save workspace',
    );
    if (selected == null) return null;
    final selectedName = baseName(selected.path);
    final path =
        '${selected.path.substring(0, selected.path.length - selectedName.length)}${workspaceFileName(selectedName)}';
    return WorkspaceFileRef(id: path, name: baseName(path));
  }

  @override
  Future<String> read(WorkspaceFileRef file) => File(file.id).readAsString();

  @override
  Future<void> write(WorkspaceFileRef file, String contents) async {
    final target = File(file.id);
    final temporary = File('${file.id}.writing');
    final backup = File('${file.id}.bak');
    await temporary.writeAsString(contents, flush: true);
    await _atomic.replace(target: target, temporary: temporary, backup: backup);
  }
}
