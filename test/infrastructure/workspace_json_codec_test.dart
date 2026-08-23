import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/domain/workspace/workspace.dart';
import 'package:visualmd/domain/workspace/workspace_id.dart';
import 'package:visualmd/domain/workspace/workspace_source.dart';
import 'package:visualmd/domain/workspace/workspace_theme.dart';
import 'package:visualmd/infrastructure/workspace/workspace_json_codec.dart';

void main() {
  const codec = WorkspaceJsonCodec();

  test('version one round-trips every durable workspace field', () {
    final workspace = Workspace(
      id: const WorkspaceId('workspace-1'),
      documentRootAbsolutePath: r'C:\Users\reader\Documents',
      theme: const SystemWorkspaceTheme(
        lightThemeId: 'paper',
        darkThemeId: 'midnight',
      ),
      markdowns: [
        WorkspaceSource(
          id: const WorkspaceSourceId('markdown-1'),
          displayName: 'Welcome.md',
          relativePath: 'Welcome.md',
        ),
      ],
      folders: [
        WorkspaceSource(
          id: const WorkspaceSourceId('folder-1'),
          displayName: 'Handbook',
          relativePath: 'Handbook',
        ),
      ],
      activeDocument: WorkspaceDocument(
        sourceId: const WorkspaceSourceId('folder-1'),
        relativePath: 'guides/start.md',
      ),
    );

    final encoded = codec.encode(workspace);
    final decoded = codec.decode(encoded);

    expect(encoded, endsWith('\n'));
    expect(decoded.id, workspace.id);
    expect(decoded.documentRootAbsolutePath, 'C:/Users/reader/Documents');
    expect(decoded.theme, workspace.theme);
    expect(decoded.markdowns, workspace.markdowns);
    expect(decoded.folders, workspace.folders);
    expect(decoded.activeDocument, workspace.activeDocument);
  });

  test('the public format rejects unknown fields instead of losing them', () {
    expect(
      () => codec.decode(
        _valid.replaceFirst(
          '"workspaceId": "workspace-1",',
          '"workspaceId": "workspace-1", "futureField": true,',
        ),
      ),
      throwsA(
        isA<WorkspaceFormatException>().having(
          (error) => error.message,
          'message',
          contains('futureField'),
        ),
      ),
    );
  });

  test('unsupported versions fail before any workspace can be restored', () {
    expect(
      () => codec.decode(_valid.replaceFirst('"version": 1', '"version": 2')),
      throwsA(
        isA<WorkspaceFormatException>().having(
          (error) => error.message,
          'message',
          contains('version 2'),
        ),
      ),
    );
  });

  test('invalid active addresses and paths fail at the format boundary', () {
    expect(
      () => codec.decode(
        _valid.replaceFirst(
          '"relativePath": "README.md"',
          '"relativePath": "../README.md"',
        ),
      ),
      throwsA(isA<WorkspaceFormatException>()),
    );
    expect(
      () => codec.decode(
        _valid.replaceFirst('"sourceId": "folder-1"', '"sourceId": "missing"'),
      ),
      throwsA(isA<WorkspaceFormatException>()),
    );
  });
}

const _valid = '''
{
  "format": "visualmd-workspace",
  "version": 1,
  "workspaceId": "workspace-1",
  "documentRootAbsolutePath": "/Users/reader/Documents",
  "theme": {"mode": "fixed", "theme": "paper"},
  "library": {
    "markdowns": [],
    "folders": [
      {"id": "folder-1", "displayName": "Notes", "relativePath": "Notes"}
    ]
  },
  "activeDocument": {"sourceId": "folder-1", "relativePath": "README.md"}
}
''';
