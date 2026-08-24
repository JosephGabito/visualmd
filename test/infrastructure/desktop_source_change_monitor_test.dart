import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/application/ports/source_change_monitor.dart';
import 'package:visualmd/infrastructure/io/desktop_source_change_monitor.dart';
import 'package:visualmd/infrastructure/io/local_folder.dart';
import 'package:visualmd/infrastructure/io/local_folder_scanner.dart';
import 'package:visualmd/infrastructure/io/local_markdown.dart';

void main() {
  test(
    'a native directory event identifies the Markdown path that changed',
    () async {
      if (!FileSystemEntity.isWatchSupported) return;
      final temporary = await Directory.systemTemp.createTemp(
        'visualmd-source-watch-',
      );
      addTearDown(() async {
        if (await temporary.exists()) await temporary.delete(recursive: true);
      });
      final markdown = File(
        '${temporary.path}${Platform.pathSeparator}README.md',
      );
      await markdown.writeAsString('# Before');
      final folders = LocalFolderRegistry('test-folders');
      final ref = folders.register(
        'Notes',
        LocalDirectory(temporary.path),
        identity: localFolderIdentity(temporary.path),
      );
      final monitor = DesktopSourceChangeMonitor(
        folders,
        LocalMarkdownRegistry('test-markdowns'),
      );
      final changed = monitor
          .watchFolder(ref)
          .where((event) => event is FolderDocumentsInvalidated)
          .cast<FolderDocumentsInvalidated>()
          .firstWhere((event) => event.relativePaths.contains('README.md'));

      // Listening starts the native watcher asynchronously. Give the operating
      // system one turn before producing the mutation under test.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await markdown.writeAsString('# After', flush: true);
      final event = await changed.timeout(const Duration(seconds: 5));

      expect(event.folder, ref);
      expect(event.relativePaths, {'README.md'});
    },
  );

  test('a targeted folder read returns current bytes without walking the root', () async {
    final temporary = await Directory.systemTemp.createTemp(
      'visualmd-source-read-',
    );
    addTearDown(() async {
      if (await temporary.exists()) await temporary.delete(recursive: true);
    });
    await Directory('${temporary.path}${Platform.pathSeparator}deep').create();
    await File(
      '${temporary.path}${Platform.pathSeparator}deep${Platform.pathSeparator}notes.md',
    ).writeAsString('# Current');
    final folders = LocalFolderRegistry('test-folders');
    final ref = folders.register('Notes', LocalDirectory(temporary.path));
    final scanner = LocalFolderScanner(folders);

    final document = await scanner.scanDocument(ref, 'deep/notes.md');

    expect(document?.relativePath, 'deep/notes.md');
    expect(document?.content, '# Current');
    expect(await scanner.scanDocument(ref, '../escape.md'), isNull);
  });
}
