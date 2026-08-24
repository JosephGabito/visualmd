import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/application/library_mutation_queue.dart';
import 'package:visualmd/application/ports/document_search.dart';
import 'package:visualmd/application/ports/folder_scanner.dart';
import 'package:visualmd/application/ports/library_repository.dart';
import 'package:visualmd/application/ports/markdown_scanner.dart';
import 'package:visualmd/application/use_cases/add_folder.dart';
import 'package:visualmd/application/use_cases/add_markdown.dart';
import 'package:visualmd/application/use_cases/move_folder.dart';
import 'package:visualmd/application/use_cases/read_document.dart';
import 'package:visualmd/application/use_cases/remove_folder.dart';
import 'package:visualmd/application/use_cases/remove_markdown.dart';
import 'package:visualmd/application/use_cases/search_documents.dart';
import 'package:visualmd/domain/library/document.dart';
import 'package:visualmd/domain/library/document_id.dart';
import 'package:visualmd/domain/library/document_source_id.dart';
import 'package:visualmd/domain/library/library.dart';
import 'package:visualmd/domain/library/library_builder.dart';
import 'package:visualmd/domain/library/library_root_id.dart';
import 'package:visualmd/domain/search/search_result.dart';
import 'package:visualmd/infrastructure/markdown/markdown_document_parser.dart';

final class FakeScanner implements FolderScanner {
  final Map<String, ScannedFolder> folders;
  FakeScanner(this.folders);

  @override
  Future<ScannedFolder> scan(FolderRef ref) async =>
      folders[ref.id] ?? (throw FolderUnavailable(ref));
}

final class ControlledScanner implements FolderScanner {
  final calls = <String>[];
  final scans = <String, Completer<ScannedFolder>>{};

  @override
  Future<ScannedFolder> scan(FolderRef ref) {
    calls.add(ref.id);
    return scans.putIfAbsent(ref.id, Completer.new).future;
  }
}

final class FakeMarkdownScanner implements MarkdownScanner {
  final Map<String, ScannedMarkdown> markdowns;

  FakeMarkdownScanner(this.markdowns);

  @override
  Future<ScannedMarkdown> scan(MarkdownRef ref) async =>
      markdowns[ref.id] ?? (throw MarkdownUnavailable(ref));
}

final class FakeRepository implements LibraryRepository {
  Library? saved;

  @override
  Future<Library?> current() async => saved;

  @override
  Future<void> save(Library library) async => saved = library;
}

final class FakeSearch implements DocumentSearch {
  List<Document> received = const [];

  @override
  Future<List<DocumentSearchResult>> find(
    SearchQuery query,
    Iterable<Document> documents,
  ) async {
    received = documents.toList();
    return const [];
  }
}

void main() {
  const notesRef = FolderRef(id: 'drop-1', name: 'notes');
  const notesId = LibraryRootId('drop-1');
  const guidesRef = FolderRef(id: 'drop-2', name: 'guides');
  const guidesId = LibraryRootId('drop-2');
  final scanner = FakeScanner({
    'drop-1': const ScannedFolder(
      name: 'notes',
      files: [
        FileEntry('README.md', '# Notes\n\n## Start'),
        FileEntry('ideas.md', 'ideas'),
      ],
    ),
    'drop-2': const ScannedFolder(
      name: 'guides',
      files: [FileEntry('README.md', '# Guides')],
    ),
  });

  AddFolder addFolder(FakeRepository repo, [FolderScanner? source]) =>
      AddFolder(
        scanner: source ?? scanner,
        repository: repo,
        mutations: LibraryMutationQueue(),
      );

  test(
    'folders append in session order and keep duplicate paths scoped',
    () async {
      final repo = FakeRepository();
      final mutations = LibraryMutationQueue();
      final useCase = AddFolder(
        scanner: scanner,
        repository: repo,
        mutations: mutations,
      );

      await useCase.execute(notesRef);
      final library = (await useCase.execute(guidesRef)).library;

      expect(library.roots.map((root) => root.name), ['notes', 'guides']);
      expect(library.documentCount, 3);
      expect(library.find(DocumentId(notesId, 'README.md'))?.title, 'Notes');
      expect(library.find(DocumentId(guidesId, 'README.md'))?.title, 'Guides');
      expect(repo.saved, same(library));
    },
  );

  test('a restored folder can return to its saved shelf position', () async {
    final repo = FakeRepository();
    final useCase = addFolder(repo);
    await useCase.execute(guidesRef);

    final result = await useCase.execute(notesRef, atIndex: 0);

    expect(result.library.roots.map((root) => root.id), [notesId, guidesId]);
  });

  test('adding the same folder refreshes it without moving it', () async {
    final repo = FakeRepository();
    final useCase = addFolder(repo);
    await useCase.execute(notesRef);
    await useCase.execute(guidesRef);
    scanner.folders['drop-1'] = const ScannedFolder(
      name: 'notes',
      files: [FileEntry('README.md', '# Refreshed')],
    );

    final result = await useCase.execute(notesRef);

    expect(result.refreshed, isTrue);
    expect(result.library.roots.map((root) => root.id), [notesId, guidesId]);
    expect(
      result.library.find(DocumentId(notesId, 'README.md'))?.title,
      'Refreshed',
    );
    scanner.folders['drop-1'] = const ScannedFolder(
      name: 'notes',
      files: [
        FileEntry('README.md', '# Notes\n\n## Start'),
        FileEntry('ideas.md', 'ideas'),
      ],
    );
  });

  test(
    'a standalone markdown joins the library and is returned for reading',
    () async {
      final repo = FakeRepository();
      final source = FakeMarkdownScanner({
        'single': const ScannedMarkdown(
          name: 'plan.md',
          content: '# Plan',
          sourceId: DocumentSourceId('/work/plan.md'),
        ),
      });

      final result = await AddMarkdown(
        scanner: source,
        repository: repo,
        mutations: LibraryMutationQueue(),
      ).execute(const MarkdownRef(id: 'single', name: 'plan.md'));

      expect(result.added, isTrue);
      expect(result.containingRoot, isNull);
      expect(result.library.roots, isEmpty);
      expect(result.library.markdowns.single.title, 'Plan');
      expect(result.library.find(result.document.id), same(result.document));
    },
  );

  test('reopening the same physical markdown refreshes its document inside a folder', () async {
    final repo = FakeRepository();
    final folderScanner = FakeScanner({
      'folder': const ScannedFolder(
        name: 'work',
        files: [
          FileEntry(
            'plan.md',
            '# Folder plan',
            sourceId: DocumentSourceId('/work/plan.md'),
          ),
        ],
      ),
    });
    await AddFolder(
      scanner: folderScanner,
      repository: repo,
      mutations: LibraryMutationQueue(),
    ).execute(const FolderRef(id: 'folder', name: 'work'));
    final source = FakeMarkdownScanner({
      'single': const ScannedMarkdown(
        name: 'plan.md',
        content: '# Standalone copy',
        sourceId: DocumentSourceId('/work/plan.md'),
      ),
    });

    final result = await AddMarkdown(
      scanner: source,
      repository: repo,
      mutations: LibraryMutationQueue(),
    ).execute(const MarkdownRef(id: 'single', name: 'plan.md'));

    expect(result.added, isFalse);
    expect(result.containingRoot, const LibraryRootId('folder'));
    expect(result.document.title, 'Standalone copy');
    expect(
      result.library.find(result.document.id)?.content,
      '# Standalone copy',
    );
    expect(result.library.markdowns, isEmpty);
  });

  test(
    'a later folder absorbs its standalone markdown into the folder tree',
    () async {
      final repo = FakeRepository();
      final mutations = LibraryMutationQueue();
      final markdownScanner = FakeMarkdownScanner({
        'single': const ScannedMarkdown(
          name: 'plan.md',
          content: '# Standalone plan',
          sourceId: DocumentSourceId('/work/plan.md'),
        ),
      });
      await AddMarkdown(
        scanner: markdownScanner,
        repository: repo,
        mutations: mutations,
      ).execute(const MarkdownRef(id: 'single', name: 'plan.md'));
      final folderScanner = FakeScanner({
        'folder': const ScannedFolder(
          name: 'work',
          files: [
            FileEntry(
              'plan.md',
              '# Folder plan',
              sourceId: DocumentSourceId('/work/plan.md'),
            ),
          ],
        ),
      });

      final result = await AddFolder(
        scanner: folderScanner,
        repository: repo,
        mutations: mutations,
      ).execute(const FolderRef(id: 'folder', name: 'work'));

      expect(result.library.markdowns, isEmpty);
      expect(
        result.adaptedDocument?.id,
        DocumentId(const LibraryRootId('folder'), 'plan.md'),
      );
      expect(result.adaptedDocument?.title, 'Folder plan');
    },
  );

  test('rapid folder additions commit in invocation order', () async {
    final repo = FakeRepository();
    final controlled = ControlledScanner();
    final mutations = LibraryMutationQueue();
    final useCase = AddFolder(
      scanner: controlled,
      repository: repo,
      mutations: mutations,
    );

    final notes = useCase.execute(notesRef);
    final guides = useCase.execute(guidesRef);
    await Future<void>.delayed(Duration.zero);
    expect(controlled.calls, ['drop-1']);
    controlled.scans['drop-1']!.complete(scanner.folders['drop-1']);
    await notes;
    await Future<void>.delayed(Duration.zero);
    expect(controlled.calls, ['drop-1', 'drop-2']);
    controlled.scans['drop-2']!.complete(scanner.folders['drop-2']);
    await guides;

    expect(repo.saved!.roots.map((root) => root.id), [notesId, guidesId]);
  });

  test(
    'folder mutations move roots and choose a deterministic neighbor',
    () async {
      final repo = FakeRepository();
      final mutations = LibraryMutationQueue();
      final add = AddFolder(
        scanner: scanner,
        repository: repo,
        mutations: mutations,
      );
      await add.execute(notesRef);
      await add.execute(guidesRef);

      final moved = await MoveFolder(
        repository: repo,
        mutations: mutations,
      ).execute(guidesId, 0);
      expect(moved.roots.map((root) => root.id), [guidesId, notesId]);

      final removed = await RemoveFolder(
        repository: repo,
        mutations: mutations,
      ).execute(guidesId, selected: DocumentId(guidesId, 'README.md'));
      expect(removed.library.roots.map((root) => root.id), [notesId]);
      expect(removed.nextDocument?.id, DocumentId(notesId, 'README.md'));
    },
  );

  test(
    'removing standalone markdowns stays nearby before returning to a folder',
    () async {
      final repo = FakeRepository();
      final mutations = LibraryMutationQueue();
      await AddFolder(
        scanner: scanner,
        repository: repo,
        mutations: mutations,
      ).execute(notesRef);
      final add = AddMarkdown(
        scanner: FakeMarkdownScanner({
          'a': const ScannedMarkdown(
            name: 'a.md',
            content: '# A',
            sourceId: null,
          ),
          'b': const ScannedMarkdown(
            name: 'b.md',
            content: '# B',
            sourceId: null,
          ),
          'c': const ScannedMarkdown(
            name: 'c.md',
            content: '# C',
            sourceId: null,
          ),
        }),
        repository: repo,
        mutations: mutations,
      );
      final a = (await add.execute(const MarkdownRef(id: 'a', name: 'a.md')))
          .document;
      final b = (await add.execute(const MarkdownRef(id: 'b', name: 'b.md')))
          .document;
      final c = (await add.execute(const MarkdownRef(id: 'c', name: 'c.md')))
          .document;
      final remove = RemoveMarkdown(repository: repo, mutations: mutations);

      final middle = await remove.execute(b.id, selected: b.id);
      expect(middle.library.markdowns.map((document) => document.id), [
        a.id,
        c.id,
      ]);
      expect(middle.nextDocument?.id, c.id);

      final last = await remove.execute(c.id, selected: c.id);
      expect(last.nextDocument?.id, a.id);

      final first = await remove.execute(a.id, selected: a.id);
      expect(first.nextDocument?.id, DocumentId(notesId, 'README.md'));

      final missing = await remove.execute(
        DocumentId(const LibraryRootId('missing'), 'missing.md'),
      );
      expect(missing.library, same(repo.saved));
      expect(missing.nextDocument, isNull);
    },
  );

  test('AddFolder surfaces unavailable folders', () async {
    final repo = FakeRepository();
    final useCase = addFolder(repo);
    await expectLater(
      () => useCase.execute(const FolderRef(id: 'gone', name: 'x')),
      throwsA(isA<FolderUnavailable>()),
    );
    final recovered = await useCase.execute(notesRef);
    expect(recovered.library.roots.single.id, notesId);
  });

  test('ReadDocument returns the document with its outline', () async {
    final repo = FakeRepository();
    await addFolder(repo).execute(notesRef);

    final reading = await ReadDocument(
      repository: repo,
      parser: const MarkdownDocumentParser(),
    ).execute(DocumentId(notesId, 'README.md'));
    expect(reading.document.title, 'Notes');
    expect(reading.outline.tableOfContents.headings.map((h) => h.text), [
      'Notes',
      'Start',
    ]);
    expect(reading.content.headings.map((h) => h.text), ['Notes', 'Start']);
  });

  test('the page and outline agree on every hostile heading anchor', () async {
    const root = LibraryRootId('headings');
    final repo = FakeRepository();
    final source = FakeScanner({
      'headings': const ScannedFolder(
        name: 'headings',
        files: [
          FileEntry(
            'headings.md',
            '#\n'
                '\n'
                '## !!! ??? ——— …\n'
                '\n'
                '### **Marked** `code` and [a link](https://example.com)\n'
                '\n'
                r'### \*literal stars\* and \[brackets\] and \`ticks\`'
                '\n'
                '\n'
                r'### \\*emphasis* and \# hash and `\* code`'
                '\n'
                '\n'
                '### &copy; &#35; &HilbertSpace; &ngE;\n'
                '\n'
                r'### &#42;literal&#42; and \&copy; and `&amp;`'
                '\n'
                '\n'
                '### &#1; control and &#x1; control\n'
                '\n'
                '## العربية 日本語 中文\n'
                '\n'
                '## Duplicate heading\n'
                '\n'
                '## Duplicate heading\n'
                '\n'
                'A multi-source **Setext** heading\n'
                'with `code` and [a link](https://example.com)\n'
                '===\n',
          ),
        ],
      ),
    });
    await addFolder(
      repo,
      source,
    ).execute(const FolderRef(id: 'headings', name: 'headings'));

    final reading = await ReadDocument(
      repository: repo,
      parser: const MarkdownDocumentParser(),
    ).execute(DocumentId(root, 'headings.md'));
    final outline = reading.outline.tableOfContents.headings;
    final content = reading.content.headings;

    expect(
      outline.map((heading) => (heading.level, heading.text, heading.anchor)),
      content.map((heading) => (heading.level, heading.text, heading.anchor)),
    );
    expect(outline.map((heading) => heading.anchor), [
      'section',
      'section-1',
      'marked-code-and-a-link',
      'literal-stars-and-brackets-and-ticks',
      'emphasis-and-hash-and-code',
      'ℋ',
      'literal-and-copy-and-amp',
      'control-and-control',
      'العربية-日本語-中文',
      'duplicate-heading',
      'duplicate-heading-1',
      'a-multi-source-setext-heading-with-code-and-a-link',
    ]);
  });

  test('ReadDocument fails clearly without a library or document', () async {
    final repo = FakeRepository();
    final useCase = ReadDocument(
      repository: repo,
      parser: const MarkdownDocumentParser(),
    );
    expect(
      () => useCase.execute(DocumentId(notesId, 'a.md')),
      throwsA(isA<NoLibraryOpen>()),
    );

    await addFolder(repo).execute(notesRef);
    expect(
      () => useCase.execute(DocumentId(notesId, 'missing.md')),
      throwsA(isA<DocumentNotFound>()),
    );
  });

  test('SearchDocuments chooses the whole library or one document', () async {
    final repo = FakeRepository();
    await addFolder(repo).execute(notesRef);
    final search = FakeSearch();
    final useCase = SearchDocuments(repository: repo, search: search);

    await useCase.execute('start');
    expect(search.received, hasLength(2));

    await useCase.execute('start', within: DocumentId(notesId, 'README.md'));
    expect(search.received.map((document) => document.id.path), ['README.md']);
  });

  test('an empty search does no work', () async {
    final search = FakeSearch();
    final results = await SearchDocuments(
      repository: FakeRepository(),
      search: search,
    ).execute('');

    expect(results, isEmpty);
    expect(search.received, isEmpty);
  });
}
