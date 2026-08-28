import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/application/ports/workspace_recovery_store.dart';
import 'package:visualmd/application/ports/workspace_session_repository.dart';
import 'package:visualmd/domain/library/library.dart';
import 'package:visualmd/domain/workspace/workspace.dart';
import 'package:visualmd/domain/workspace/workspace_id.dart';
import 'package:visualmd/domain/workspace/workspace_theme.dart';
import 'package:visualmd/infrastructure/memory/in_memory_reader_state.dart';
import 'package:visualmd/infrastructure/memory/in_memory_workspace_restoration.dart';
import 'package:visualmd/infrastructure/memory/in_memory_workspace_session_repository.dart';
import 'package:visualmd/infrastructure/recovery/recovering_workspace_state.dart';

void main() {
  test('journal failure never rolls back a committed live session', () async {
    final state = InMemoryReaderState();
    final failing = _FailingRecovery();
    final sessions = RecoveringWorkspaceSessionRepository(
      InMemoryWorkspaceSessionRepository(state),
      failing,
    );
    final restoration = RecoveringWorkspaceRestoration(
      InMemoryWorkspaceRestoration(state),
      failing,
    );
    final first = WorkspaceSession(
      workspace: _workspace('first'),
      file: null,
      dirty: true,
    );
    final second = WorkspaceSession(
      workspace: _workspace('second'),
      file: null,
      dirty: true,
    );

    await sessions.save(first);
    expect(await sessions.current(), same(first));

    await restoration.replace(Library.empty(), second);
    expect(await sessions.current(), same(second));
    expect(state.library!.isEmpty, isTrue);
    expect(failing.attempts, 2);
  });
}

Workspace _workspace(String id) => Workspace(
  id: WorkspaceId(id),
  documentRootAbsolutePath: null,
  theme: const FixedWorkspaceTheme('paper'),
);

final class _FailingRecovery implements WorkspaceRecoveryStore {
  var attempts = 0;

  @override
  Future<Workspace?> load() async => null;

  @override
  Future<void> save(Workspace workspace) async {
    attempts++;
    throw StateError('disk unavailable');
  }
}
