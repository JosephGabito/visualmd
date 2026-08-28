// ignore_for_file: prefer_initializing_formals — the public parameter hides the private field.

import 'dart:io';

import '../../application/ports/workspace_codec.dart';
import '../../application/ports/workspace_recovery_store.dart';
import '../../domain/workspace/workspace.dart';
import 'desktop_atomic_files.dart';
import 'reader_files.dart';

/// A private, machine-local journal for the last reading room.
///
/// It uses the workspace codec because recovery must retain the exact source
/// identities and absolute document root used to rebase relative paths. It is
/// not a public workspace binding: loading it never grants automatic writes to
/// a user-owned file.
final class DesktopWorkspaceRecoveryStore implements WorkspaceRecoveryStore {
  final ReaderFiles _files;
  final WorkspaceCodec _codec;
  final DesktopAtomicFiles _atomic;

  const DesktopWorkspaceRecoveryStore(
    this._files,
    this._codec, {
    DesktopAtomicFiles atomic = const DesktopAtomicFiles(),
  }) : _atomic = atomic;

  File get _journal => _files.sessionJournal;
  File get _backup => File('${_journal.path}.bak');

  @override
  Future<Workspace?> load() async {
    final primary = await _decode(_journal);
    if (primary != null) return primary;
    return _decode(_backup);
  }

  Future<Workspace?> _decode(File file) async {
    if (!await file.exists()) return null;
    try {
      return _codec.decode(await file.readAsString());
    } on Object {
      return null;
    }
  }

  @override
  Future<void> save(Workspace workspace) async {
    final temporary = File('${_journal.path}.writing');
    await temporary.writeAsString(_codec.encode(workspace), flush: true);

    // If the primary is corrupt while the backup is still usable, do not let
    // replacement rotate that corrupt primary over the only good fallback.
    if (await _journal.exists() &&
        await _decode(_journal) == null &&
        await _decode(_backup) != null) {
      await _journal.delete();
      await temporary.rename(_journal.path);
      return;
    }
    await _atomic.replace(
      target: _journal,
      temporary: temporary,
      backup: _backup,
    );
  }
}
