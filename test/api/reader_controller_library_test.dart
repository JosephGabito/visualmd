import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/api/reader_controller.dart';
import 'package:visualmd/api/reader_source_opener.dart';
import 'package:visualmd/application/document_source_reader.dart';
import 'package:visualmd/application/library_mutation_queue.dart';
import 'package:visualmd/application/ports/folder_document_scanner.dart';
import 'package:visualmd/application/ports/folder_scanner.dart';
import 'package:visualmd/application/ports/markdown_scanner.dart';
import 'package:visualmd/application/ports/reader_source_picker.dart';
import 'package:visualmd/application/use_cases/add_folder.dart';
import 'package:visualmd/application/use_cases/add_markdown.dart';
import 'package:visualmd/application/use_cases/enrich_folder_titles.dart';
import 'package:visualmd/application/use_cases/move_folder.dart';
import 'package:visualmd/application/use_cases/read_document.dart';
import 'package:visualmd/application/use_cases/remove_folder.dart';
import 'package:visualmd/application/use_cases/remove_markdown.dart';
import 'package:visualmd/application/use_cases/search_documents.dart';
import 'package:visualmd/domain/library/document_id.dart';
import 'package:visualmd/domain/library/document_source_id.dart';
import 'package:visualmd/domain/library/library_builder.dart';
import 'package:visualmd/domain/library/library_root_id.dart';
import 'package:visualmd/infrastructure/markdown/markdown_document_parser.dart';
import 'package:visualmd/infrastructure/memory/in_memory_library_repository.dart';
import 'package:visualmd/infrastructure/search/literal_document_search.dart';
import 'package:visualmd/presentation/theme/theme_registry.dart';

final class _Scanner implements FolderScanner, FolderDocumentScanner {
  final folders = <String, ScannedFolder>{
    'a': const ScannedFolder(
      name: 'alpha',
      files: [
        FileEntry('README.md', '# Alpha'),
        FileEntry('guide.md', '# Alpha guide'),
      ],
    ),
    'b': const ScannedFolder(
      name: 'beta',
      files: [
        FileEntry('README.md', '# Beta'),
        FileEntry('guide.md', '# Beta guide'),
      ],
    ),
  };

  @override
  Future<ScannedFolder> scan(FolderRef ref) async => folders[ref.id]!;

  @override
  Future<ScannedFolderDocument?> scanDocument(
    FolderRef folder,
    String relativePath,
  ) async {
    final entry = folders[folder.id]!.files
        .where((candidate) => candidate.path == relativePath)
        .firstOrNull;
    final content = entry?.content;
    return content == null
        ? null
        : ScannedFolderDocument(
            relativePath: relativePath,
            content: content,
            sourceId: entry?.sourceId,
          );
  }
}

final class _MarkdownScanner implements MarkdownScanner {
  final markdowns = <String, ScannedMarkdown>{};

  @override
  Future<ScannedMarkdown> scan(MarkdownRef ref) async => markdowns[ref.id]!;
}

final class _DeferredMetadataScanner
    implements FolderScanner, FolderMetadataScanner, FolderDocumentScanner {
  final documentStarted = Completer<void>();
  final document = Completer<ScannedFolderDocument?>();
  final titles = Completer<ScannedFolder>();

  @override
  Future<ScannedFolder> scan(FolderRef ref) => scanMetadata(ref);

  @override
  Future<ScannedFolder> scanMetadata(FolderRef ref) async =>
      const ScannedFolder(
        name: 'alpha',
        titlesDeferred: true,
        files: [
          FileEntry(
            'README.md',
            null,
            sourceId: DocumentSourceId('/alpha/README.md'),
          ),
        ],
      );

  @override
  Future<ScannedFolder> enrichTitles(FolderRef ref, ScannedFolder metadata) =>
      titles.future;

  @override
  Future<ScannedFolderDocument?> scanDocument(
    FolderRef folder,
    String relativePath,
  ) {
    if (!documentStarted.isCompleted) documentStarted.complete();
    return document.future;
  }
}

final class _ReaderSourcePicker implements ReaderSourcePicker {
  List<ReaderSourceSelection> selected = const [];

  @override
  Future<List<ReaderSourceSelection>> pick() async => selected;
}

final class _DeferredReaderSourcePicker implements ReaderSourcePicker {
  final result = Completer<List<ReaderSourceSelection>>();
  var calls = 0;

  @override
  Future<List<ReaderSourceSelection>> pick() {
    calls++;
    return result.future;
  }
}

void main() {
  const alpha = FolderRef(id: 'a', name: 'alpha');
  const beta = FolderRef(id: 'b', name: 'beta');
  const alphaId = LibraryRootId('a');
  const betaId = LibraryRootId('b');

  late _Scanner scanner;
  late _MarkdownScanner markdownScanner;
  late _ReaderSourcePicker readerSourcePicker;
  late ReaderController controller;

  setUp(() {
    scanner = _Scanner();
    markdownScanner = _MarkdownScanner();
    readerSourcePicker = _ReaderSourcePicker();
    final repository = InMemoryLibraryRepository();
    final mutations = LibraryMutationQueue();
    const parser = MarkdownDocumentParser();
    final sources = DocumentSourceReader(
      folderDocuments: scanner,
      markdowns: markdownScanner,
    );
    controller = ReaderController(
      addFolder: AddFolder(
        scanner: scanner,
        repository: repository,
        mutations: mutations,
      ),
      addMarkdown: AddMarkdown(
        scanner: markdownScanner,
        repository: repository,
        mutations: mutations,
      ),
      removeFolder: RemoveFolder(repository: repository, mutations: mutations),
      removeMarkdown: RemoveMarkdown(
        repository: repository,
        mutations: mutations,
      ),
      moveFolder: MoveFolder(repository: repository, mutations: mutations),
      readDocument: ReadDocument(
        repository: repository,
        parser: parser,
        sources: sources,
      ),
      searchDocuments: SearchDocuments(
        repository: repository,
        search: LiteralDocumentSearch(parser: parser),
        sources: sources,
      ),
      pickFolder: () async => null,
      sampleFolder: alpha,
      themes: ThemeRegistry(),
    );
  });

  test(
    'Open routes every selected source through its existing use case',
    () async {
      markdownScanner.markdowns['plan'] = const ScannedMarkdown(
        name: 'plan.md',
        content: '# Plan',
        sourceId: DocumentSourceId('/outside/plan.md'),
      );
      readerSourcePicker.selected = const [
        FolderSourceSelection(alpha),
        MarkdownSourceSelection(MarkdownRef(id: 'plan', name: 'plan.md')),
      ];

      await ReaderSourceOpener(readerSourcePicker, controller).call();

      expect(controller.library!.roots.single.id, alphaId);
      expect(controller.library!.markdowns.single.title, 'Plan');
      expect(controller.reading!.document.title, 'Plan');
    },
  );

  test(
    'folder opening publishes filename metadata before source and title reads',
    () async {
      final deferred = _DeferredMetadataScanner();
      final repository = InMemoryLibraryRepository();
      final mutations = LibraryMutationQueue();
      const parser = MarkdownDocumentParser();
      final sources = DocumentSourceReader(
        folderDocuments: deferred,
        markdowns: markdownScanner,
      );
      final titlePublished = Completer<void>();
      final subject = ReaderController(
        addFolder: AddFolder(
          scanner: deferred,
          metadataScanner: deferred,
          repository: repository,
          mutations: mutations,
        ),
        enrichFolderTitles: EnrichFolderTitles(
          scanner: deferred,
          repository: repository,
          mutations: mutations,
        ),
        addMarkdown: AddMarkdown(
          scanner: markdownScanner,
          repository: repository,
          mutations: mutations,
        ),
        removeFolder: RemoveFolder(
          repository: repository,
          mutations: mutations,
        ),
        removeMarkdown: RemoveMarkdown(
          repository: repository,
          mutations: mutations,
        ),
        moveFolder: MoveFolder(repository: repository, mutations: mutations),
        readDocument: ReadDocument(
          repository: repository,
          parser: parser,
          sources: sources,
        ),
        searchDocuments: SearchDocuments(
          repository: repository,
          search: LiteralDocumentSearch(parser: parser),
          sources: sources,
        ),
        pickFolder: () async => null,
        sampleFolder: alpha,
        themes: ThemeRegistry(),
      );
      addTearDown(subject.dispose);
      subject.addListener(() {
        final title = subject.library
            ?.find(DocumentId(alphaId, 'README.md'))
            ?.indexedTitle;
        if (title == 'Authored alpha' && !titlePublished.isCompleted) {
          titlePublished.complete();
        }
      });

      final opening = subject.addFolder(alpha);
      await deferred.documentStarted.future;

      expect(subject.opening, isTrue);
      expect(subject.reading, isNull);
      expect(
        subject.library!.find(DocumentId(alphaId, 'README.md'))!.title,
        'README',
      );

      deferred.document.complete(
        const ScannedFolderDocument(
          relativePath: 'README.md',
          content: '# Authored alpha',
          sourceId: DocumentSourceId('/alpha/README.md'),
        ),
      );
      await opening;
      deferred.titles.complete(
        const ScannedFolder(
          name: 'alpha',
          files: [
            FileEntry(
              'README.md',
              null,
              sourceId: DocumentSourceId('/alpha/README.md'),
              title: 'Authored alpha',
            ),
          ],
        ),
      );
      await titlePublished.future;

      expect(subject.reading!.document.title, 'Authored alpha');
      expect(
        subject.library!.find(DocumentId(alphaId, 'README.md'))!.title,
        'Authored alpha',
      );
    },
  );

  test(
    'Open ignores a second request while its native picker is active',
    () async {
      final picker = _DeferredReaderSourcePicker();
      final opener = ReaderSourceOpener(picker, controller);

      final first = opener.call();
      final second = opener.call();
      expect(picker.calls, 1);

      picker.result.complete(const []);
      await Future.wait([first, second]);
    },
  );

  test(
    'adding, arranging and removing roots preserves reading intent',
    () async {
      await controller.addFolder(alpha);
      await controller.addFolder(beta);
      expect(controller.reading?.document.id, DocumentId(betaId, 'README.md'));

      await controller.openDocument(DocumentId(alphaId, 'guide.md'));
      await controller.moveFolder(betaId, 0);
      expect(controller.library!.roots.map((root) => root.id), [
        betaId,
        alphaId,
      ]);
      expect(controller.reading?.document.id, DocumentId(alphaId, 'guide.md'));

      await controller.removeFolder(alphaId);
      expect(controller.library!.roots.map((root) => root.id), [betaId]);
      expect(controller.reading?.document.id, DocumentId(betaId, 'README.md'));

      await controller.removeFolder(betaId);
      expect(controller.library, isNull);
      expect(controller.reading, isNull);
    },
  );

  test(
    'the sample command opens its existing root without duplicating it',
    () async {
      await controller.addFolder(alpha);
      await controller.addFolder(beta);
      expect(controller.reading?.document.id, DocumentId(betaId, 'README.md'));

      await controller.openSampleLibrary();
      await controller.openSampleLibrary();

      expect(controller.library!.roots.map((root) => root.id), [
        alphaId,
        betaId,
      ]);
      expect(controller.reading?.document.id, DocumentId(alphaId, 'README.md'));
    },
  );

  test(
    'refresh keeps a surviving selection and replaces its content',
    () async {
      await controller.addFolder(alpha);
      await controller.openDocument(DocumentId(alphaId, 'guide.md'));
      scanner.folders['a'] = const ScannedFolder(
        name: 'alpha',
        files: [FileEntry('guide.md', '# Refreshed guide')],
      );

      await controller.addFolder(alpha);

      expect(controller.library!.roots, hasLength(1));
      expect(controller.reading?.document.id, DocumentId(alphaId, 'guide.md'));
      expect(controller.reading?.document.title, 'Refreshed guide');
    },
  );

  test('a standalone markdown opens above the folder library', () async {
    markdownScanner.markdowns['plan'] = const ScannedMarkdown(
      name: 'plan.md',
      content: '# Plan',
      sourceId: DocumentSourceId('/outside/plan.md'),
    );

    await controller.addMarkdown(
      const MarkdownRef(id: 'plan', name: 'plan.md'),
    );

    expect(controller.library!.markdowns.single.title, 'Plan');
    expect(controller.reading!.document.title, 'Plan');
    expect(controller.expandRequest, isNull);
  });

  test(
    'removing standalone markdown keeps reading nearby without touching roots',
    () async {
      await controller.addFolder(alpha);
      markdownScanner.markdowns['plan'] = const ScannedMarkdown(
        name: 'plan.md',
        content: '# Plan',
        sourceId: null,
      );
      markdownScanner.markdowns['notes'] = const ScannedMarkdown(
        name: 'notes.md',
        content: '# Notes',
        sourceId: null,
      );
      await controller.addMarkdown(
        const MarkdownRef(id: 'plan', name: 'plan.md'),
      );
      final plan = controller.reading!.document.id;
      await controller.addMarkdown(
        const MarkdownRef(id: 'notes', name: 'notes.md'),
      );
      final notes = controller.reading!.document.id;

      await controller.removeMarkdown(plan);
      expect(controller.reading?.document.id, notes);
      expect(controller.library!.roots.single.id, alphaId);

      await controller.removeMarkdown(notes);
      expect(controller.library!.markdowns, isEmpty);
      expect(controller.library!.roots.single.id, alphaId);
      expect(controller.reading?.document.id, DocumentId(alphaId, 'README.md'));
    },
  );

  test(
    'removing the only standalone markdown returns to the welcome screen',
    () async {
      markdownScanner.markdowns['plan'] = const ScannedMarkdown(
        name: 'plan.md',
        content: '# Plan',
        sourceId: null,
      );
      await controller.addMarkdown(
        const MarkdownRef(id: 'plan', name: 'plan.md'),
      );

      await controller.removeMarkdown(controller.reading!.document.id);

      expect(controller.library, isNull);
      expect(controller.reading, isNull);
    },
  );

  test(
    'dropping a library document opens it and requests its path expanded',
    () async {
      scanner.folders['a'] = const ScannedFolder(
        name: 'alpha',
        files: [
          FileEntry(
            'README.md',
            '# Alpha',
            sourceId: DocumentSourceId('/alpha/README.md'),
          ),
        ],
      );
      markdownScanner.markdowns['readme'] = const ScannedMarkdown(
        name: 'README.md',
        content: '# Ignored duplicate',
        sourceId: DocumentSourceId('/alpha/README.md'),
      );
      await controller.addFolder(alpha);

      await controller.addMarkdown(
        const MarkdownRef(id: 'readme', name: 'README.md'),
      );

      expect(controller.library!.markdowns, isEmpty);
      expect(controller.reading!.document.id, DocumentId(alphaId, 'README.md'));
      expect(controller.expandRequest?.id, DocumentId(alphaId, 'README.md'));
      expect(controller.expandRequest?.revision, 1);
    },
  );

  test(
    'removing the last folder hands reading to a standalone markdown',
    () async {
      markdownScanner.markdowns['plan'] = const ScannedMarkdown(
        name: 'plan.md',
        content: '# Plan',
        sourceId: DocumentSourceId('/outside/plan.md'),
      );
      await controller.addMarkdown(
        const MarkdownRef(id: 'plan', name: 'plan.md'),
      );
      await controller.addFolder(alpha);
      expect(controller.reading!.document.id.rootId, alphaId);

      await controller.removeFolder(alphaId);

      expect(controller.library, isNotNull);
      expect(controller.library!.roots, isEmpty);
      expect(controller.reading!.document.title, 'Plan');
    },
  );

  test(
    'a later folder absorbs an open standalone and expands to its new path',
    () async {
      markdownScanner.markdowns['plan'] = const ScannedMarkdown(
        name: 'plan.md',
        content: '# Standalone plan',
        sourceId: DocumentSourceId('/alpha/plan.md'),
      );
      await controller.addMarkdown(
        const MarkdownRef(id: 'plan', name: 'plan.md'),
      );
      expect(controller.library!.markdowns, hasLength(1));
      scanner.folders['a'] = const ScannedFolder(
        name: 'alpha',
        files: [
          FileEntry(
            'plan.md',
            '# Folder plan',
            sourceId: DocumentSourceId('/alpha/plan.md'),
          ),
        ],
      );

      await controller.addFolder(alpha);

      expect(controller.library!.markdowns, isEmpty);
      expect(controller.reading!.document.id, DocumentId(alphaId, 'plan.md'));
      expect(controller.reading!.document.title, 'Folder plan');
      expect(controller.expandRequest?.id, DocumentId(alphaId, 'plan.md'));
      expect(controller.expandRequest?.revision, 1);
    },
  );

  test('relative links never cross from one root into another', () async {
    await controller.addFolder(alpha);
    await controller.addFolder(beta);
    await controller.openDocument(DocumentId(alphaId, 'README.md'));

    final target = controller.resolveLink('guide.md');

    expect(target, isA<DocumentLink>());
    expect((target! as DocumentLink).id, DocumentId(alphaId, 'guide.md'));
  });

  test(
    'link targets keep anchor, document, and external intent distinct',
    () async {
      await controller.addFolder(alpha);
      await controller.openDocument(DocumentId(alphaId, 'README.md'));

      final anchor = controller.resolveLink('#setup')! as AnchorLink;
      final duplicate = controller.resolveLink('#setup-1')! as AnchorLink;
      final spaced = controller.resolveLink('#chapter%20one')! as AnchorLink;
      final document =
          controller.resolveLink('guide.md#details')! as DocumentLink;
      final spacedDocument =
          controller.resolveLink('guide.md#chapter%20one')! as DocumentLink;
      final malformed = controller.resolveLink('#chapter%ZZone')! as AnchorLink;
      final external =
          controller.resolveLink('https://example.com/guide')! as ExternalLink;
      final email =
          controller.resolveLink('mailto:reader@example.com')! as ExternalLink;
      final chat =
          controller.resolveLink('xmpp:reader@example.com')! as ExternalLink;

      expect(anchor.anchor, 'setup');
      expect(duplicate.anchor, 'setup-1');
      expect(spaced.anchor, 'chapter one');
      expect(document.id, DocumentId(alphaId, 'guide.md'));
      expect(document.anchor, 'details');
      expect(spacedDocument.anchor, 'chapter one');
      expect(malformed.anchor, 'chapter%ZZone');
      expect(external.url, 'https://example.com/guide');
      expect(email.url, 'mailto:reader@example.com');
      expect(chat.url, 'xmpp:reader@example.com');
      expect(controller.resolveLink(''), isNull);
      expect(controller.resolveLink('missing.md'), isNull);
      expect(controller.resolveLink('javascript:alert(1)'), isNull);
      expect(controller.resolveLink('data:text/html,unsafe'), isNull);
      expect(controller.resolveLink('vbscript:msgbox(1)'), isNull);
    },
  );
}
