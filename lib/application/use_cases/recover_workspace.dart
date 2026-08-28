// ignore_for_file: prefer_initializing_formals — named parameters describe the composition contract.

import '../ports/workspace_recovery_store.dart';
import 'open_workspace.dart';

/// Restores the last private reading-room journal without binding it to a
/// user-owned workspace file.
final class RecoverWorkspace {
  final WorkspaceRecoveryStore _recovery;
  final OpenWorkspace _open;

  const RecoverWorkspace({
    required WorkspaceRecoveryStore recovery,
    required OpenWorkspace open,
  }) : _recovery = recovery,
       _open = open;

  Future<OpenedWorkspace?> execute() async {
    try {
      final workspace = await _recovery.load();
      return workspace == null
          ? null
          : await _open.restore(
              workspace,
              null,
              preserveUnresolvedActive: true,
            );
    } on Object {
      // Recovery must never turn a damaged or unreadable private journal into
      // a launch failure. The composition root will create an empty room.
      return null;
    }
  }
}
