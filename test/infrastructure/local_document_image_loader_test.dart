import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/domain/library/document_id.dart';
import 'package:visualmd/domain/library/library_root_id.dart';
import 'package:visualmd/infrastructure/io/local_document_image_loader.dart';
import 'package:visualmd/infrastructure/io/local_folder.dart';
import 'package:visualmd/infrastructure/io/local_markdown.dart';

void main() {
  late Directory sandbox;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('visual-md-images-');
  });

  tearDown(() async {
    if (await sandbox.exists()) await sandbox.delete(recursive: true);
  });

  test('a folder image is read relative to its markdown directory', () async {
    final guide = Directory('${sandbox.path}/guide');
    final images = Directory('${sandbox.path}/images');
    await guide.create();
    await images.create();
    await File('${guide.path}/page.md').writeAsString('# Page');
    await File('${images.path}/map.png').writeAsBytes([1, 2, 3, 4]);

    final folders = LocalFolderRegistry('test-folder');
    final ref = folders.register(
      'notes',
      LocalDirectory(sandbox.path),
      identity: sandbox.path,
    );
    final loader = LocalDocumentImageLoader(
      folders,
      LocalMarkdownRegistry('test-markdown'),
    );

    expect(
      await loader.load(
        DocumentId(LibraryRootId(ref.id), 'guide/page.md'),
        '../images/map.png',
      ),
      [1, 2, 3, 4],
    );
  });

  test('a missing or escaping folder image is an ordinary miss', () async {
    final folders = LocalFolderRegistry('test-folder');
    final ref = folders.register('notes', LocalDirectory(sandbox.path));
    final loader = LocalDocumentImageLoader(
      folders,
      LocalMarkdownRegistry('test-markdown'),
    );
    final document = DocumentId(LibraryRootId(ref.id), 'page.md');

    expect(await loader.load(document, 'missing.png'), isNull);
    expect(await loader.load(document, '../outside.png'), isNull);
    expect(await loader.load(document, 'https://example.com/map.png'), isNull);
  });

  test('a symlink cannot carry an image outside the offered folder', () async {
    final outside = await Directory.systemTemp.createTemp('visualmd-outside-');
    addTearDown(() => outside.delete(recursive: true));
    final secret = File('${outside.path}/secret.png');
    await secret.writeAsBytes([1, 2, 3]);
    await Link('${sandbox.path}/secret.png').create(secret.path);

    final folders = LocalFolderRegistry('test-folder');
    final ref = folders.register('notes', LocalDirectory(sandbox.path));
    final loader = LocalDocumentImageLoader(
      folders,
      LocalMarkdownRegistry('test-markdown'),
    );
    final document = DocumentId(LibraryRootId(ref.id), 'page.md');

    expect(await loader.load(document, 'secret.png'), isNull);
  });

  test('a filesystem root remains a valid authorised folder', () async {
    final image = File('${sandbox.path}/root-image.png');
    await image.writeAsBytes([8, 9, 10]);
    final filesystemRoot = _filesystemRootOf(sandbox).path;
    final relativeImage = image.absolute.path
        .substring(filesystemRoot.length)
        .replaceAll(Platform.pathSeparator, '/');

    final folders = LocalFolderRegistry('test-folder');
    final ref = folders.register(
      'root',
      LocalDirectory(filesystemRoot),
      identity: filesystemRoot,
    );
    final loader = LocalDocumentImageLoader(
      folders,
      LocalMarkdownRegistry('test-markdown'),
    );

    expect(
      await loader.load(
        DocumentId(LibraryRootId(ref.id), 'page.md'),
        relativeImage,
      ),
      [8, 9, 10],
    );
  });

  test('a standalone markdown may resolve a neighbour it can access', () async {
    final markdownFile = File('${sandbox.path}/page.md');
    final imageFile = File('${sandbox.path}/map.png');
    await markdownFile.writeAsString('# Page');
    await imageFile.writeAsBytes([5, 6, 7]);

    final markdowns = LocalMarkdownRegistry('test-markdown');
    final ref = markdowns.register('page.md', LocalMarkdown(markdownFile.path));
    final loader = LocalDocumentImageLoader(
      LocalFolderRegistry('test-folder'),
      markdowns,
    );

    expect(
      await loader.load(
        DocumentId(LibraryRootId('standalone-markdown:${ref.id}'), 'page.md'),
        'map.png',
      ),
      [5, 6, 7],
    );
  });
}

Directory _filesystemRootOf(Directory directory) {
  var root = directory.absolute;
  while (root.parent.path != root.path) {
    root = root.parent;
  }
  return root;
}
