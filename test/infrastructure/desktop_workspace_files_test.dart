import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/application/ports/workspace_files.dart';
import 'package:visualmd/infrastructure/io/desktop_atomic_files.dart';
import 'package:visualmd/infrastructure/io/desktop_workspace_files.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the save panel result remains the exact authorised path', () async {
    const selectedPath = '/Users/reader/Documents/Notes.json';
    final adapter = DesktopWorkspaceFiles(
      saveLocation: (suggestedName) async {
        expect(suggestedName, 'Notes.visualmd-workspace.json');
        return selectedPath;
      },
    );

    final selected = await adapter.pickSave(
      suggestedName: 'Notes.visualmd-workspace.json',
    );

    expect(
      selected,
      const WorkspaceFileRef(id: selectedPath, name: 'Notes.json'),
    );
  });

  test(
    'macOS sends the authorised target and contents to the native writer',
    () async {
      const channel = MethodChannel('com.visualmd.visualmd/atomic-files');
      MethodCall? received;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            received = call;
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );

      await const DesktopAtomicFiles().writeSelected(
        target: File('/Users/reader/Documents/Notes.json'),
        contents: '{"version":1}\n',
      );

      expect(received?.method, 'writeSelected');
      expect(received?.arguments, {
        'target': '/Users/reader/Documents/Notes.json',
        'contents': '{"version":1}\n',
      });
    },
    skip: !Platform.isMacOS,
  );

  test(
    'the non-sandbox fallback keeps the previous workspace as a last-good copy',
    () async {
      final root = await Directory.systemTemp.createTemp('visualmd-workspace-');
      addTearDown(() => root.delete(recursive: true));
      final path = '${root.path}/project.visualmd-workspace.json';
      final file = WorkspaceFileRef(
        id: path,
        name: 'project.visualmd-workspace.json',
      );
      final adapter = DesktopWorkspaceFiles(
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
