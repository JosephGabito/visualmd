import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/application/ports/workspace_source_access.dart';
import 'package:visualmd/domain/workspace/workspace.dart';
import 'package:visualmd/domain/workspace/workspace_id.dart';
import 'package:visualmd/domain/workspace/workspace_source.dart';
import 'package:visualmd/domain/workspace/workspace_theme.dart';
import 'package:visualmd/infrastructure/io/desktop_atomic_files.dart';
import 'package:visualmd/infrastructure/io/desktop_bookmarks.dart';
import 'package:visualmd/infrastructure/io/desktop_workspace_source_access.dart';
import 'package:visualmd/infrastructure/io/local_folder.dart';
import 'package:visualmd/infrastructure/io/local_markdown.dart';
import 'package:visualmd/infrastructure/io/reader_files.dart';
import 'package:visualmd/infrastructure/io/scoped_access.dart';

void main() {
  late Directory root;
  late ReaderFiles files;
  late LocalFolderRegistry folders;
  late LocalMarkdownRegistry markdowns;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('visualmd-source-access-');
    files = ReaderFiles(
      Directory('${root.path}/reader'),
      atomic: const DesktopAtomicFiles(useNative: false),
    );
    await files.root.create(recursive: true);
    folders = LocalFolderRegistry('folder');
    markdowns = LocalMarkdownRegistry('markdown');
  });

  tearDown(() => root.delete(recursive: true));

  test(
    'a restored directory is validated while its bookmark scope is active',
    () async {
      final resolvedPath = '${root.path}/resolved/notes';
      final originalBookmark = Uint8List.fromList([1, 2]);
      final refreshedBookmark = Uint8List.fromList([3, 4]);
      await files.writeWorkspaceAccess(
        'workspace',
        'source',
        path: '${root.path}/old/notes',
        bookmark: originalBookmark,
      );
      final scope = _MaterializingScope.directory(resolvedPath);
      final access = DesktopWorkspaceSourceAccess(
        folders,
        markdowns,
        files,
        access: scope,
        resolveBookmark: (_) async => BookmarkResolution(
          path: resolvedPath,
          bookmark: refreshedBookmark,
          refreshed: true,
        ),
      );

      final ref = await access.restoreFolder(_workspace(), _source());

      expect(scope.bookmarks.single, refreshedBookmark);
      expect(folders.lookup(ref), isA<LocalDirectory>());
      expect((folders.lookup(ref)! as LocalDirectory).path, resolvedPath);
      expect(await Directory(resolvedPath).exists(), isFalse);
    },
  );

  test(
    'a restored Markdown file is validated while its bookmark scope is active',
    () async {
      final resolvedPath = '${root.path}/resolved/guide.md';
      final bookmark = Uint8List.fromList([5, 6]);
      await files.writeWorkspaceAccess(
        'workspace',
        'source',
        path: '${root.path}/old/guide.md',
        bookmark: bookmark,
      );
      final scope = _MaterializingScope.file(resolvedPath);
      final access = DesktopWorkspaceSourceAccess(
        folders,
        markdowns,
        files,
        access: scope,
        resolveBookmark: (_) async => BookmarkResolution(
          path: resolvedPath,
          bookmark: bookmark,
          refreshed: false,
        ),
      );

      final ref = await access.restoreMarkdown(_workspace(), _source());

      expect(scope.bookmarks.single, bookmark);
      expect(markdowns.lookup(ref)?.path, resolvedPath);
      expect(await File(resolvedPath).exists(), isFalse);
    },
  );

  test(
    'a machine-local stored path survives an unavailable bookmark resolution',
    () async {
      final storedPath = '${root.path}/machine-local/notes';
      final bookmark = Uint8List.fromList([7, 8]);
      await files.writeWorkspaceAccess(
        'workspace',
        'source',
        path: storedPath,
        bookmark: bookmark,
      );
      final scope = _MaterializingScope.directory(storedPath);
      final access = DesktopWorkspaceSourceAccess(
        folders,
        markdowns,
        files,
        access: scope,
        resolveBookmark: (_) async => null,
      );

      final ref = await access.restoreFolder(_workspace(), _source());

      expect((folders.lookup(ref)! as LocalDirectory).path, storedPath);
      expect(scope.bookmarks.single, bookmark);
    },
  );

  test(
    'a native bookmark failure becomes a reconnectable unavailable source',
    () async {
      final bookmark = Uint8List.fromList([9, 10]);
      await files.writeWorkspaceAccess(
        'workspace',
        'source',
        path: '${root.path}/stored/notes',
        bookmark: bookmark,
      );
      final access = DesktopWorkspaceSourceAccess(
        folders,
        markdowns,
        files,
        resolveBookmark: (_) async => throw StateError('native failure'),
      );

      await expectLater(
        access.restoreFolder(_workspace(), _source()),
        throwsA(
          isA<WorkspaceSourceUnavailable>().having(
            (error) => error.source,
            'source',
            _source(),
          ),
        ),
      );
    },
  );
}

Workspace _workspace() => Workspace(
  id: const WorkspaceId('workspace'),
  documentRootAbsolutePath: '/portable/root',
  theme: const FixedWorkspaceTheme('paper'),
);

WorkspaceSource _source() => WorkspaceSource(
  id: const WorkspaceSourceId('source'),
  displayName: 'Notes',
  relativePath: 'portable-notes',
);

final class _MaterializingScope implements ScopedAccess {
  final String path;
  final bool isDirectory;
  final List<Uint8List?> bookmarks = [];

  _MaterializingScope.directory(this.path) : isDirectory = true;

  _MaterializingScope.file(this.path) : isDirectory = false;

  @override
  Future<T> within<T>(Uint8List? bookmark, Future<T> Function() body) async {
    bookmarks.add(bookmark);
    if (isDirectory) {
      await Directory(path).create(recursive: true);
    } else {
      await File(path).parent.create(recursive: true);
      await File(path).writeAsString('# Guide');
    }
    try {
      return await body();
    } finally {
      if (isDirectory) {
        await Directory(path).delete(recursive: true);
      } else {
        await File(path).delete();
      }
    }
  }
}
