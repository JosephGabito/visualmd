import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/domain/library/document.dart';
import 'package:visualmd/domain/library/document_id.dart';
import 'package:visualmd/domain/library/library_builder.dart';
import 'package:visualmd/domain/library/library_root_id.dart';

void main() {
  const rootId = LibraryRootId('docs');
  group('LibraryBuilder', () {
    test('keeps only markdown files and drops folders without any', () {
      final library = LibraryBuilder.buildRoot(
        id: rootId,
        name: 'docs',
        files: const [
          FileEntry('README.md', '# Docs'),
          FileEntry('assets/logo.png', 'binary'),
          FileEntry('guide/intro.markdown', 'intro'),
          FileEntry('guide/images/diagram.svg', '<svg/>'),
        ],
      );

      expect(library.documentCount, 2);
      expect(library.folder.folders.map((f) => f.name), ['guide']);
      expect(library.folder.folders.single.folders, isEmpty);
    });

    test('shelves README first, then natural order', () {
      final library = LibraryBuilder.buildRoot(
        id: rootId,
        name: 'docs',
        files: const [
          FileEntry('10-deploy.md', ''),
          FileEntry('2-setup.md', ''),
          FileEntry('README.md', ''),
          FileEntry('1-intro.md', ''),
          FileEntry('Zebra.md', ''),
          FileEntry('apple.md', ''),
        ],
      );

      expect(library.folder.documents.map((d) => d.fileName), [
        'README.md',
        '1-intro.md',
        '2-setup.md',
        '10-deploy.md',
        'apple.md',
        'Zebra.md',
      ]);
    });

    test('orders folders naturally and nests them', () {
      final library = LibraryBuilder.buildRoot(
        id: rootId,
        name: 'docs',
        files: const [
          FileEntry('01-system-wiring/a.md', ''),
          FileEntry('00-foundation/b.md', ''),
          FileEntry('00-foundation/deep/er/c.md', ''),
        ],
      );

      final folders = library.folder.folders;
      expect(folders.map((f) => f.name), ['00-foundation', '01-system-wiring']);
      expect(folders.first.folders.single.path, '00-foundation/deep');
      expect(
        folders.first.folders.single.folders.single.path,
        '00-foundation/deep/er',
      );
      expect(
        library.find(DocumentId(rootId, '00-foundation/deep/er/c.md')),
        isNotNull,
      );
    });

    test('opening document prefers the root README', () {
      final library = LibraryBuilder.buildRoot(
        id: rootId,
        name: 'docs',
        files: const [
          FileEntry('a/readme.md', 'nested'),
          FileEntry('a/first.md', ''),
          FileEntry('Readme.md', '# Root'),
        ],
      );
      expect(library.openingDocument!.id.path, 'Readme.md');

      final noReadme = LibraryBuilder.buildRoot(
        id: rootId,
        name: 'docs',
        files: const [FileEntry('z/last.md', ''), FileEntry('a/first.md', '')],
      );
      expect(noReadme.openingDocument!.id.path, 'a/first.md');
    });

    test('ignores duplicate paths and normalises separators', () {
      final library = LibraryBuilder.buildRoot(
        id: rootId,
        name: 'docs',
        files: const [
          FileEntry('a\\b.md', 'first'),
          FileEntry('/a/b.md', 'second'),
        ],
      );
      expect(library.documentCount, 1);
      expect(library.find(DocumentId(rootId, 'a/b.md'))!.content, 'first');
    });

    test('DocumentId resolves relative links from its folder', () {
      final id = DocumentId(rootId, 'guide/advanced/links.md');
      expect(
        id.resolve('../02-the-outline.md').path,
        'guide/02-the-outline.md',
      );
      expect(id.resolve('./sibling.md').path, 'guide/advanced/sibling.md');
      expect(id.resolve('/README.md').path, 'README.md');
      expect(id.resolve('../../../../escape.md').path, 'escape.md');
      expect(id.resolve('my%20notes.md').path, 'guide/advanced/my notes.md');
    });

    test('never shelves markdown inside hidden folders', () {
      const excluded = [
        '.git',
        '.obsidian',
        '__pycache__',
        '__pypackages__',
        'bower_components',
        'Carthage',
        'DerivedData',
        'jspm_packages',
        'node_modules',
        'Pods',
        'site-packages',
        'vendor',
        'venv',
      ];
      final library = LibraryBuilder.buildRoot(
        id: rootId,
        name: 'docs',
        files: [
          const FileEntry('README.md', ''),
          for (final folder in excluded)
            FileEntry('$folder/pkg/README.md', 'nope'),
          const FileEntry('guide/.drafts/secret.md', 'nope'),
          const FileEntry('build/README.md', 'yes'),
          const FileEntry('dist/README.md', 'yes'),
          const FileEntry('out/README.md', 'yes'),
          const FileEntry('target/README.md', 'yes'),
        ],
      );
      expect(library.documents.map((d) => d.id.path), [
        'README.md',
        'build/README.md',
        'dist/README.md',
        'out/README.md',
        'target/README.md',
      ]);
    });

    test('a library with no markdown is empty', () {
      final library = LibraryBuilder.buildRoot(
        id: rootId,
        name: 'x',
        files: const [FileEntry('a.txt', '')],
      );
      expect(library.documentCount, 0);
      expect(library.openingDocument, isNull);
    });

    test(
      'path mutations share untouched branches and sort only changed ones',
      () {
        final library = LibraryBuilder.buildRoot(
          id: rootId,
          name: 'docs',
          files: const [
            FileEntry('alpha/old.md', ''),
            FileEntry('stable/one.md', ''),
            FileEntry('stable/two.md', ''),
          ],
        );
        final stable = library.folder.folders.singleWhere(
          (folder) => folder.name == 'stable',
        );

        final changed = library.applyDocumentChanges({
          DocumentId(rootId, 'alpha/old.md'): null,
          DocumentId(rootId, 'alpha/10-new.md'): Document(
            id: DocumentId(rootId, 'alpha/10-new.md'),
          ),
          DocumentId(rootId, 'alpha/2-new.md'): Document(
            id: DocumentId(rootId, 'alpha/2-new.md'),
          ),
        });

        expect(
          identical(
            changed.folder.folders.singleWhere(
              (folder) => folder.name == 'stable',
            ),
            stable,
          ),
          isTrue,
        );
        expect(
          changed.folder.folders
              .singleWhere((folder) => folder.name == 'alpha')
              .documents
              .map((document) => document.fileName),
          ['2-new.md', '10-new.md'],
        );
      },
    );

    test('path mutation creates ancestors and removes an empty branch', () {
      final library = LibraryBuilder.buildRoot(
        id: rootId,
        name: 'docs',
        files: const [FileEntry('old/only.md', '')],
      );
      final replacement = DocumentId(rootId, 'new/deep/README.md');

      final changed = library.applyDocumentChanges({
        DocumentId(rootId, 'old/only.md'): null,
        replacement: Document(id: replacement),
      });

      expect(changed.folder.folders.map((folder) => folder.name), ['new']);
      expect(changed.find(replacement), isNotNull);
      expect(changed.find(DocumentId(rootId, 'old/only.md')), isNull);
    });
  });
}
