import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/application/ports/folder_scanner.dart';
import 'package:visualmd/infrastructure/io/local_folder.dart';
import 'package:visualmd/infrastructure/io/local_folder_scanner.dart';
import 'package:visualmd/infrastructure/io/local_markdown.dart';
import 'package:visualmd/infrastructure/io/local_markdown_scanner.dart';
import 'package:visualmd/infrastructure/io/scoped_access.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('visualmd-');
    Future<void> put(String path, String content) async {
      final file = File('${root.path}/$path');
      await file.parent.create(recursive: true);
      await file.writeAsString(content);
    }

    await put('README.md', '# Root');
    await put('guide/intro.md', 'intro');
    await put('guide/deep/er/page.markdown', 'deep');
    await put('guide/script.py', 'print(1)');
    await put('.git/HEAD', 'ref');
    await put('.hidden/secret.md', 'nope');
    await put('node_modules/pkg/README.md', 'nope');
    await put('vendor/pkg/README.md', 'nope');
    await put('venv/pkg/README.md', 'nope');
    await put('Pods/pkg/README.md', 'nope');
    await File('${root.path}/latin1.md')
        .writeAsBytes([0x23, 0x20, 0xE9, 0x0A]); // "# é" in latin-1
  });

  tearDown(() => root.delete(recursive: true));

  test(
    'walks a directory, keeping only markdown outside hidden folders',
    () async {
      final registry = LocalFolderRegistry('test');
      final ref = registry.register('lib', LocalDirectory(root.path));
      final scanned = await LocalFolderScanner(registry).scan(ref);

      expect(
        scanned.name,
        baseName(root.path),
      ); // a library is named after its folder
      expect(scanned.files.map((f) => f.path).toSet(), {
        'README.md',
        'guide/intro.md',
        'guide/deep/er/page.markdown',
        'latin1.md',
      });
      expect(
        scanned.files
            .firstWhere((f) => f.path == 'guide/deep/er/page.markdown')
            .content,
        isNull,
      );
      expect(
        scanned.files.firstWhere((f) => f.path == 'README.md').title,
        'Root',
      );
      final opened = await LocalFolderScanner(registry)
          .scanDocument(ref, 'guide/deep/er/page.markdown');
      expect(opened?.content, 'deep');
    },
  );

  test('discovers the shelf before reading authored titles', () async {
    final registry = LocalFolderRegistry('test');
    final ref = registry.register('lib', LocalDirectory(root.path));
    final scanner = LocalFolderScanner(registry);

    final metadata = await scanner.scanMetadata(ref);

    expect(metadata.titlesDeferred, isTrue);
    expect(metadata.files, hasLength(4));
    expect(metadata.files.every((file) => file.title == null), isTrue);
    expect(metadata.files.every((file) => file.content == null), isTrue);
    expect(metadata.files.every((file) => file.sourceId != null), isTrue);

    final enriched = await scanner.enrichTitles(ref, metadata);

    expect(enriched.titlesDeferred, isFalse);
    expect(
      enriched.files.firstWhere((file) => file.path == 'README.md').title,
      'Root',
    );
  });

  test(
    'survives non-UTF-8 bytes instead of failing the whole library',
    () async {
      final registry = LocalFolderRegistry('test');
      final ref = registry.register('lib', LocalDirectory(root.path));
      final scanned = await LocalFolderScanner(registry).scan(ref);
      final latin = scanned.files.firstWhere((f) => f.path == 'latin1.md');
      expect(latin.content, isNull);
      final opened = await LocalFolderScanner(registry)
          .scanDocument(ref, 'latin1.md');
      expect(opened?.content, startsWith('# '));
    },
  );

  test('loose files become a flat library', () async {
    final registry = LocalFolderRegistry('test');
    final ref = registry.register(
      'Dropped files',
      LocalFiles(
        name: 'Dropped files',
        files: [
          ('${root.path}/README.md', null),
          ('${root.path}/guide/script.py', null),
        ],
      ),
    );
    final scanned = await LocalFolderScanner(registry).scan(ref);
    expect(scanned.files.map((f) => f.path), ['README.md']);
  });

  test('title reads overlap without exceeding the desktop IO budget', () async {
    final loose = <(String, Uint8List?)>[];
    for (var index = 0; index < 20; index++) {
      final file = File('${root.path}/book-$index.md');
      await file.writeAsString('# Book $index');
      loose.add((file.path, null));
    }
    final access = _CountingAccess();
    final registry = LocalFolderRegistry('test');
    final ref = registry.register(
      'Books',
      LocalFiles(name: 'Books', files: loose),
    );

    final scanned = await LocalFolderScanner(
      registry,
      access: access,
    ).scan(ref);

    expect(scanned.files.map((file) => file.title), [
      for (var index = 0; index < 20; index++) 'Book $index',
    ]);
    expect(access.maximumActive, 8);
  });

  test(
    'folder and single-file scans share one physical source identity',
    () async {
      final folderRegistry = LocalFolderRegistry('folders');
      final folderRef = folderRegistry.register(
        'root',
        LocalDirectory(root.path),
      );
      final folder = await LocalFolderScanner(folderRegistry).scan(folderRef);
      final markdownRegistry = LocalMarkdownRegistry('markdowns');
      final markdownRef = markdownRegistry.register(
        'README.md',
        LocalMarkdown('${root.path}/README.md'),
      );
      final markdown = await LocalMarkdownScanner(markdownRegistry)
          .scan(markdownRef);

      final folderReadme = folder.files.firstWhere(
        (file) => file.path == 'README.md',
      );
      expect(folderReadme.sourceId, isNotNull);
      expect(markdown.sourceId, folderReadme.sourceId);
    },
  );

  test('unknown refs are reported as unavailable', () {
    final scanner = LocalFolderScanner(LocalFolderRegistry('test'));
    expect(
      () => scanner.scan(const FolderRef(id: 'nope', name: 'x')),
      throwsA(isA<FolderUnavailable>()),
    );
  });
}

final class _CountingAccess implements ScopedAccess {
  var _active = 0;
  var maximumActive = 0;

  @override
  Future<T> within<T>(Uint8List? bookmark, Future<T> Function() body) async {
    _active++;
    if (_active > maximumActive) maximumActive = _active;
    await Future<void>.delayed(const Duration(milliseconds: 5));
    try {
      return await body();
    } finally {
      _active--;
    }
  }
}
