import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/domain/workspace/workspace.dart';
import 'package:visualmd/domain/workspace/workspace_id.dart';
import 'package:visualmd/domain/workspace/workspace_source.dart';
import 'package:visualmd/domain/workspace/workspace_theme.dart';

void main() {
  final folder = WorkspaceSource(
    id: const WorkspaceSourceId('folder-1'),
    displayName: 'Notes',
    relativePath: 'notes',
  );

  test(
    'a workspace keeps stable source order and normalizes Windows roots',
    () {
      final workspace = Workspace(
        id: const WorkspaceId('workspace-1'),
        documentRootAbsolutePath: r'C:\Users\reader\Documents\',
        theme: const FixedWorkspaceTheme('paper'),
        folders: [folder],
      );

      expect(workspace.documentRootAbsolutePath, 'C:/Users/reader/Documents');
      expect(workspace.folders, [folder]);
    },
  );

  test('a workspace rejects duplicate identity across source kinds', () {
    expect(
      () => Workspace(
        id: const WorkspaceId('workspace-1'),
        documentRootAbsolutePath: '/Users/reader',
        theme: const FixedWorkspaceTheme('paper'),
        folders: [folder],
        markdowns: [
          WorkspaceSource(
            id: folder.id,
            displayName: 'Notes.md',
            relativePath: 'Notes.md',
          ),
        ],
      ),
      throwsArgumentError,
    );
  });

  test('the active document must belong to one of the workspace sources', () {
    expect(
      () => Workspace(
        id: const WorkspaceId('workspace-1'),
        documentRootAbsolutePath: '/Users/reader',
        theme: const FixedWorkspaceTheme('paper'),
        folders: [folder],
        activeDocument: WorkspaceDocument(
          sourceId: const WorkspaceSourceId('somewhere-else'),
          relativePath: 'README.md',
        ),
      ),
      throwsArgumentError,
    );
  });

  test('serialized source paths cannot escape their document root', () {
    for (final path in ['', '/notes', r'notes\README.md', 'notes/../secret']) {
      expect(
        () => WorkspaceSource(
          id: const WorkspaceSourceId('source'),
          displayName: 'Notes',
          relativePath: path,
        ),
        throwsArgumentError,
        reason: path,
      );
    }
  });

  test('dot addresses a source at the document root', () {
    expect(
      WorkspaceSource(
        id: const WorkspaceSourceId('source'),
        displayName: 'Notes',
        relativePath: '.',
      ).relativePath,
      '.',
    );
  });

  test('a Windows drive root remains an absolute document root', () {
    final workspace = Workspace(
      id: const WorkspaceId('workspace'),
      documentRootAbsolutePath: r'C:\',
      theme: const FixedWorkspaceTheme('paper'),
    );

    expect(workspace.documentRootAbsolutePath, 'C:/');
  });
}
