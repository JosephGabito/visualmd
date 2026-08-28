import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/application/ports/external_open_item.dart';
import 'package:visualmd/application/ports/reader_source_picker.dart';
import 'package:visualmd/infrastructure/io/desktop_atomic_files.dart';
import 'package:visualmd/infrastructure/io/desktop_external_open_items.dart';
import 'package:visualmd/infrastructure/io/desktop_workspace_files.dart';
import 'package:visualmd/infrastructure/io/local_markdown.dart';
import 'package:visualmd/infrastructure/io/scoped_access.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Finder records become ordered opaque refs with their sandbox authority',
    () async {
      final root = await Directory.systemTemp.createTemp('visualmd-finder-');
      addTearDown(() => root.delete(recursive: true));
      final markdownPath = '${root.path}/notes.md';
      final workspacePath = '${root.path}/room.visualmd-workspace.json';
      await File(markdownPath).writeAsString('# Notes\n');
      await File(workspacePath).writeAsString('{"format":"visualmd"}\n');

      final markdowns = LocalMarkdownRegistry('markdown');
      final access = _Access();
      final workspaces = DesktopWorkspaceFiles(
        atomic: DesktopAtomicFiles(useNative: false),
        access: access,
      );
      final adapter = DesktopExternalOpenItems(
        markdowns,
        workspaces,
        channel: const MethodChannel('visualmd.test/external-open-items'),
        announceReady: false,
      );
      addTearDown(adapter.dispose);

      final received = adapter.stream.take(2).toList();
      adapter.accept([
        {
          'path': markdownPath,
          'bookmark': Uint8List.fromList([1, 2]),
        },
        {
          'path': workspacePath,
          'bookmark': Uint8List.fromList([3, 4]),
        },
        {'path': '${root.path}/notes.json'},
        {'path': '${root.path}/image.png'},
      ]);

      final items = await received;
      final markdown = items.first as ExternalReaderSource;
      final markdownRef = (markdown.source as MarkdownSourceSelection).ref;
      expect(markdownRef.id, isNot(markdownPath));
      expect(markdownRef.name, 'notes.md');
      expect(markdowns.lookup(markdownRef)?.path, markdownPath);
      expect(markdowns.lookup(markdownRef)?.bookmark, [1, 2]);

      final workspace = items.last as ExternalWorkspace;
      expect(workspace.file.id, isNot(workspacePath));
      expect(workspace.file.name, 'room.visualmd-workspace.json');
      expect(await workspaces.pickOpen(), workspace.file);
      expect(await workspaces.read(workspace.file), '{"format":"visualmd"}\n');
      await workspaces.write(workspace.file, '{"format":"updated"}\n');
      expect(
        await File(workspacePath).readAsString(),
        '{"format":"updated"}\n',
      );
      expect(access.bookmarks, [
        [3, 4],
        [3, 4],
      ]);
    },
  );

  test(
    'Dart announces readiness after installing the cold-launch receiver',
    () async {
      const channel = MethodChannel('visualmd.test/external-open-ready');
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
      final adapter = DesktopExternalOpenItems(
        LocalMarkdownRegistry('markdown'),
        DesktopWorkspaceFiles(),
        channel: channel,
      );
      addTearDown(adapter.dispose);

      await Future<void>.delayed(Duration.zero);

      expect(received?.method, 'ready');
    },
  );
}

final class _Access implements ScopedAccess {
  final List<Uint8List?> bookmarks = [];

  @override
  Future<T> within<T>(Uint8List? bookmark, Future<T> Function() body) async {
    bookmarks.add(bookmark);
    return body();
  }
}
