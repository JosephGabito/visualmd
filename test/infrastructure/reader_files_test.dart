import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/presentation/theme/theme_registry.dart';
import 'package:visualmd/infrastructure/io/desktop_atomic_files.dart';
import 'package:visualmd/infrastructure/io/reader_files.dart';

void main() {
  late Directory root;
  late ReaderFiles files;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('visualmd-files-');
    files = ReaderFiles(
      root,
      atomic: const DesktopAtomicFiles(useNative: false),
    );
    await files.themesDirectory.create(recursive: true);
  });

  tearDown(() => root.delete(recursive: true));

  Future<void> writeTheme(String name, String contents) =>
      File('${files.themesDirectory.path}/$name').writeAsString(contents);

  test(
    'reads every .json theme in name order and ignores everything else',
    () async {
      await writeTheme('b-nord.json', '{"id":"b"}');
      await writeTheme('a-sepia.json', '{"id":"a"}');
      await writeTheme('README.md', '# not a theme');
      await writeTheme('notes.txt', 'nor this');

      final documents = await files.readThemeDocuments();
      expect(documents.map((d) => d.origin), ['a-sepia.json', 'b-nord.json']);
      expect(documents.first.json, contains('"a"'));
    },
  );

  test(
    'a themes folder that is not there yields no themes, not an error',
    () async {
      await files.themesDirectory.delete(recursive: true);
      expect(await files.readThemeDocuments(), isEmpty);
    },
  );

  test('preferences round-trip and survive a corrupt file', () async {
    expect(await files.readPreference('theme'), isNull);
    await files.writePreference('theme', '{"mode":"fixed","theme":"nord"}');
    await files.writePreference('other', 'value');
    expect(
      await files.readPreference('theme'),
      '{"mode":"fixed","theme":"nord"}',
    );
    expect(await files.readPreference('other'), 'value');

    await File('${root.path}/preferences.json').writeAsString('{not json');
    expect(await files.readPreference('theme'), isNull);
    await files.writePreference('theme', 'again');
    expect(await files.readPreference('theme'), 'again');
  });

  test(
    'the folder feeds the registry: good themes load, bad ones are reported',
    () async {
      await writeTheme('sepia.json', '''
{"id":"sepia","name":"Sepia","brightness":"light","palette":{
  "paper":"#f4ecd8","panel":"#ece3cc","border":"#d8ccb0","ink":"#3b2f2f",
  "muted":"#7a6a5a","accent":"#8b4513","codeBackground":"#ebe2c9"}}''');
      await writeTheme('broken.json', '{"id":"oops","name":"Oops"}');

      final registry = ThemeRegistry.fromDocuments(
        await files.readThemeDocuments(),
      );
      expect(registry.byId('sepia')?.name, 'Sepia');
      expect(registry.light.map((t) => t.id), containsAll(['paper', 'sepia']));
      expect(registry.errors.single.origin, 'broken.json');
      expect(registry.errors.single.reason, contains('brightness'));
    },
  );

  test('the first-run README documents the format it actually parses', () {
    expect(themesReadme, contains('"codeBackground"'));
    expect(themesReadme, contains('"brightness"'));
    expect(themesReadme, contains('accentSoft'));
  });

  test(
    'Save As carries source access to the forked workspace identity',
    () async {
      await files.writeWorkspaceAccess(
        'original',
        'folder',
        path: '/work/notes',
        bookmark: Uint8List.fromList([1, 2, 3]),
      );

      await files.forkWorkspaceAccess('original', 'fork', [
        'folder',
        'missing',
      ]);

      final copied = await files.readWorkspaceAccess('fork', 'folder');
      expect(copied!.path, '/work/notes');
      expect(copied.bookmark, [1, 2, 3]);
      expect(await files.readWorkspaceAccess('fork', 'missing'), isNull);
    },
  );
}
