import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/domain/workspace/workspace.dart';
import 'package:visualmd/domain/workspace/workspace_id.dart';
import 'package:visualmd/domain/workspace/workspace_source.dart';
import 'package:visualmd/domain/workspace/workspace_theme.dart';
import 'package:visualmd/infrastructure/io/desktop_atomic_files.dart';
import 'package:visualmd/infrastructure/io/desktop_workspace_recovery_store.dart';
import 'package:visualmd/infrastructure/io/reader_files.dart';
import 'package:visualmd/infrastructure/workspace/workspace_json_codec.dart';

void main() {
  late Directory root;
  late ReaderFiles files;
  late DesktopWorkspaceRecoveryStore recovery;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('visualmd-recovery-');
    files = ReaderFiles(
      root,
      atomic: const DesktopAtomicFiles(useNative: false),
    );
    recovery = DesktopWorkspaceRecoveryStore(
      files,
      const WorkspaceJsonCodec(),
      atomic: const DesktopAtomicFiles(useNative: false),
    );
  });

  tearDown(() => root.delete(recursive: true));

  test(
    'private recovery preserves the exact room without entering preferences',
    () async {
      final room = _room('room-1');

      await recovery.save(room);
      final restored = (await recovery.load())!;

      expect(restored.id, room.id);
      expect(restored.documentRootAbsolutePath, '/Users/reader/Documents');
      expect(restored.markdowns, room.markdowns);
      expect(restored.folders, room.folders);
      expect(restored.activeDocument, room.activeDocument);
      expect(restored.theme, room.theme);
      expect(
        files.sessionJournal.path,
        File('${root.path}${Platform.pathSeparator}session.json').path,
      );
      expect(
        File('${root.path}${Platform.pathSeparator}preferences.json')
            .existsSync(),
        isFalse,
      );
    },
  );

  test(
    'a corrupt primary falls back without rotating over its good backup',
    () async {
      final first = _room('first');
      final second = _room('second');
      final third = _room('third');
      await recovery.save(first);
      await recovery.save(second);
      await files.sessionJournal.writeAsString('{broken');

      expect((await recovery.load())!.id, first.id);

      await recovery.save(third);
      expect((await recovery.load())!.id, third.id);
      final backup = File('${files.sessionJournal.path}.bak');
      expect(
        const WorkspaceJsonCodec().decode(await backup.readAsString()).id,
        first.id,
      );
    },
  );
}

Workspace _room(String id) {
  final markdown = WorkspaceSource(
    id: const WorkspaceSourceId('markdown'),
    displayName: 'Plan.md',
    relativePath: 'Plan.md',
  );
  final folder = WorkspaceSource(
    id: const WorkspaceSourceId('folder'),
    displayName: 'Handbook',
    relativePath: 'Handbook',
  );
  return Workspace(
    id: WorkspaceId(id),
    documentRootAbsolutePath: '/Users/reader/Documents',
    theme: const SystemWorkspaceTheme(
      lightThemeId: 'paper',
      darkThemeId: 'midnight',
    ),
    markdowns: [markdown],
    folders: [folder],
    activeDocument: WorkspaceDocument(
      sourceId: folder.id,
      relativePath: 'guides/start.md',
    ),
  );
}
