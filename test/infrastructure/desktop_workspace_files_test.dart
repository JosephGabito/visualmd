import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/application/ports/workspace_files.dart';
import 'package:visualmd/infrastructure/io/desktop_atomic_files.dart';
import 'package:visualmd/infrastructure/io/desktop_workspace_files.dart';

void main() {
  test(
    'replacement keeps the previous workspace as a last-good copy',
    () async {
      final root = await Directory.systemTemp.createTemp('visualmd-workspace-');
      addTearDown(() => root.delete(recursive: true));
      final path = '${root.path}/project.visualmd-workspace.json';
      final file = WorkspaceFileRef(
        id: path,
        name: 'project.visualmd-workspace.json',
      );
      const adapter = DesktopWorkspaceFiles(
        atomic: DesktopAtomicFiles(useNative: false),
      );

      await adapter.write(file, '{"version":1}\n');
      await adapter.write(file, '{"version":2}\n');

      expect(await File(path).readAsString(), '{"version":2}\n');
      expect(await File('$path.bak').readAsString(), '{"version":1}\n');
      expect(await File('$path.writing').exists(), isFalse);
    },
  );
}
