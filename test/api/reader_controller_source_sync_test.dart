import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/api/reader_controller.dart';
import 'package:visualmd/application/library_mutation_queue.dart';
import 'package:visualmd/application/ports/folder_document_scanner.dart';
import 'package:visualmd/application/ports/folder_scanner.dart';
import 'package:visualmd/application/ports/markdown_scanner.dart';
import 'package:visualmd/application/ports/source_change_monitor.dart';
import 'package:visualmd/application/source_watch_coordinator.dart';
import 'package:visualmd/application/use_cases/add_folder.dart';
import 'package:visualmd/application/use_cases/add_markdown.dart';
import 'package:visualmd/application/use_cases/move_folder.dart';
import 'package:visualmd/application/use_cases/read_document.dart';
import 'package:visualmd/application/use_cases/refresh_source.dart';
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

void main() {
  const folder = FolderRef(id: 'notes', name: 'Notes');
  const rootId = LibraryRootId('notes');
  final guide = DocumentId(rootId, 'guide.md');

  late _Source source;
  late _Monitor monitor;
  late ReaderController controller;

  setUp(() {
    source = _Source();
    monitor = _Monitor();
    final repository = InMemoryLibraryRepository();
    final mutations = LibraryMutationQueue();
    const parser = MarkdownDocumentParser();
    late final SourceWatchCoordinator changes;
    changes = SourceWatchCoordinator(
      monitor: monitor,
      refresh: RefreshSource(
        folders: source,
        folderDocuments: source,
        markdowns: _MarkdownScanner(),
        repository: repository,
        mutations: mutations,
      ),
      currentSelection: () => controller.reading?.document.id,
      quietPeriod: Duration.zero,
    );
    controller = ReaderController(
      addFolder: AddFolder(
        scanner: source,
        repository: repository,
        mutations: mutations,
      ),
      addMarkdown: AddMarkdown(
        scanner: _MarkdownScanner(),
        repository: repository,
        mutations: mutations,
      ),
      removeFolder: RemoveFolder(repository: repository, mutations: mutations),
      removeMarkdown: RemoveMarkdown(
        repository: repository,
        mutations: mutations,
      ),
      moveFolder: MoveFolder(repository: repository, mutations: mutations),
      readDocument: ReadDocument(repository: repository, parser: parser),
      searchDocuments: SearchDocuments(
        repository: repository,
        search: LiteralDocumentSearch(parser: parser),
      ),
      pickFolder: () async => null,
      sampleFolder: folder,
      themes: ThemeRegistry(),
      sourceChanges: changes,
    );
  });

  tearDown(() {
    controller.dispose();
  });

  test(
    'a source refresh keeps the active document and replaces every projection',
    () async {
      await controller.addFolder(folder);
      await controller.openDocument(guide);
      final revision = controller.contentRevision;
      source.guide = '# After\n\n## New outline\n\nnew searchable phrase';
      final updated = Completer<void>();
      void observe() {
        if (controller.contentRevision > revision && !updated.isCompleted) {
          updated.complete();
        }
      }

      controller.addListener(observe);
      addTearDown(() => controller.removeListener(observe));

      monitor.folder.add(
        FolderDocumentsInvalidated(folder, const ['guide.md']),
      );
      await updated.future.timeout(const Duration(seconds: 1));

      expect(controller.reading?.document.id, guide);
      expect(controller.reading?.document.content, source.guide);
      expect(
        controller.reading?.outline.tableOfContents.headings.last.text,
        'New outline',
      );
      expect(
        await controller.search('searchable phrase', within: guide),
        hasLength(1),
      );
      expect(controller.contentRevision, revision + 1);
    },
  );

  test('watch failures remain visible after the library is open', () async {
    await controller.addFolder(folder);
    final reported = Completer<void>();
    void observe() {
      if (controller.error != null && !reported.isCompleted) {
        reported.complete();
      }
    }

    controller.addListener(observe);
    addTearDown(() => controller.removeListener(observe));

    monitor.folder.add(
      const SourceWatchFailed('Notes', 'permission was revoked'),
    );
    await reported.future.timeout(const Duration(seconds: 1));

    expect(controller.error, contains('permission was revoked'));
  });
}

final class _Source implements FolderScanner, FolderDocumentScanner {
  var guide = '# Before\n\n## Old outline\n\nold phrase';

  @override
  Future<ScannedFolder> scan(FolderRef ref) async => ScannedFolder(
    name: 'Notes',
    files: [
      const FileEntry('README.md', '# Notes'),
      FileEntry(
        'guide.md',
        guide,
        sourceId: const DocumentSourceId('/notes/guide.md'),
      ),
    ],
  );

  @override
  Future<ScannedFolderDocument?> scanDocument(
    FolderRef folder,
    String relativePath,
  ) async => ScannedFolderDocument(
    relativePath: relativePath,
    content: guide,
    sourceId: const DocumentSourceId('/notes/guide.md'),
  );
}

final class _MarkdownScanner implements MarkdownScanner {
  @override
  Future<ScannedMarkdown> scan(MarkdownRef ref) =>
      throw MarkdownUnavailable(ref);
}

final class _Monitor implements SourceChangeMonitor {
  final folder = StreamController<SourceChange>.broadcast();

  @override
  Stream<SourceChange> watchFolder(FolderRef folder) => this.folder.stream;

  @override
  Stream<SourceChange> watchMarkdown(MarkdownRef markdown) =>
      const Stream.empty();
}
