import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/application/library_mutation_queue.dart';
import 'package:visualmd/application/ports/folder_document_scanner.dart';
import 'package:visualmd/application/ports/folder_scanner.dart';
import 'package:visualmd/application/ports/library_repository.dart';
import 'package:visualmd/application/ports/markdown_scanner.dart';
import 'package:visualmd/application/ports/source_change_monitor.dart';
import 'package:visualmd/application/ports/workspace_mutation_committer.dart';
import 'package:visualmd/application/source_watch_coordinator.dart';
import 'package:visualmd/application/use_cases/refresh_source.dart';
import 'package:visualmd/domain/library/document_id.dart';
import 'package:visualmd/domain/library/document_source_id.dart';
import 'package:visualmd/domain/library/library.dart';
import 'package:visualmd/domain/library/library_builder.dart';
import 'package:visualmd/domain/library/library_root_id.dart';

void main() {
  const folder = FolderRef(id: 'notes', name: 'Notes');
  const markdown = MarkdownRef(id: 'plan', name: 'plan.md');
  const rootId = LibraryRootId('notes');
  final readme = DocumentId(rootId, 'README.md');
  final ideas = DocumentId(rootId, 'ideas.md');

  Library folderLibrary() => Library(
    roots: [
      LibraryBuilder.buildRoot(
        id: rootId,
        name: 'Notes',
        files: const [
          FileEntry('README.md', '# Before'),
          FileEntry('ideas.md', '# Ideas'),
        ],
      ),
    ],
  );

  test(
    'one invalidated path rereads one document and preserves selection',
    () async {
      final repository = _Repository(folderLibrary());
      final documents = _FolderDocuments({
        'README.md': const ScannedFolderDocument(
          relativePath: 'README.md',
          content: '# After',
          sourceId: DocumentSourceId('/notes/README.md'),
        ),
      });
      final refresh = _refresh(repository, folderDocuments: documents);

      final result = await refresh.execute(
        FolderDocumentsInvalidated(folder, const ['README.md']),
        selected: readme,
      );

      expect(documents.calls, ['README.md']);
      expect(result.library.find(readme)?.content, '# After');
      expect(result.library.find(ideas)?.content, '# Ideas');
      expect(result.activeDocument, readme);
      expect(result.changedDocuments, {readme});
    },
  );

  test(
    'create and delete rebuild the tree and move a deleted selection',
    () async {
      final repository = _Repository(folderLibrary());
      final documents = _FolderDocuments({
        'ideas.md': null,
        'deep/new.md': const ScannedFolderDocument(
          relativePath: 'deep/new.md',
          content: '# New',
          sourceId: DocumentSourceId('/notes/deep/new.md'),
        ),
      });
      final workspace = _Workspace();
      final refresh = _refresh(
        repository,
        folderDocuments: documents,
        workspace: workspace,
      );

      final result = await refresh.execute(
        FolderDocumentsInvalidated(folder, const ['ideas.md', 'deep/new.md']),
        selected: ideas,
      );

      expect(result.library.find(ideas), isNull);
      expect(result.library.find(DocumentId(rootId, 'deep/new.md')), isNotNull);
      expect(result.activeDocument, readme);
      expect(workspace.active, readme);
    },
  );

  test(
    'a standalone invalidation replaces bytes under the same identity',
    () async {
      final standaloneId = DocumentId(
        const LibraryRootId('standalone-markdown:plan'),
        'plan.md',
      );
      final repository = _Repository(
        Library(
          roots: const [],
          markdowns: [
            LibraryBuilder.buildRoot(
              id: standaloneId.rootId,
              name: 'standalone',
              files: const [FileEntry('plan.md', '# Before')],
            ).openingDocument!,
          ],
        ),
      );
      final markdowns = _MarkdownScanner({
        'plan': const ScannedMarkdown(
          name: 'plan.md',
          content: '# After',
          sourceId: DocumentSourceId('/plan.md'),
        ),
      });
      final refresh = _refresh(repository, markdowns: markdowns);

      final result = await refresh.execute(
        const MarkdownInvalidated(markdown),
        selected: standaloneId,
      );

      expect(result.library.find(standaloneId)?.content, '# After');
      expect(result.activeDocument, standaloneId);
    },
  );

  test(
    'noisy events coalesce and always read after the quiet period',
    () async {
      final repository = _Repository(folderLibrary());
      final documents = _FolderDocuments({
        'README.md': const ScannedFolderDocument(
          relativePath: 'README.md',
          content: '# Final',
          sourceId: null,
        ),
      });
      final monitor = _Monitor();
      final coordinator = SourceWatchCoordinator(
        monitor: monitor,
        refresh: _refresh(repository, folderDocuments: documents),
        currentSelection: () => readme,
        quietPeriod: const Duration(milliseconds: 15),
      );
      addTearDown(() async {
        await coordinator.dispose();
        await monitor.close();
      });
      coordinator.watchFolder(folder);
      final update = coordinator.events
          .where((event) => event is SourceSynchronized)
          .cast<SourceSynchronized>()
          .first;

      monitor.folder.add(
        FolderDocumentsInvalidated(folder, const ['README.md']),
      );
      monitor.folder.add(
        FolderDocumentsInvalidated(folder, const ['README.md']),
      );
      monitor.folder.add(
        FolderDocumentsInvalidated(folder, const ['README.md']),
      );
      final result = await update.timeout(const Duration(seconds: 1));

      expect(documents.calls, ['README.md']);
      expect(result.result.library.find(readme)?.content, '# Final');
    },
  );

  test('an invalidated watch cannot commit after it is replaced', () async {
    final repository = _Repository(folderLibrary());
    final documents = _BlockingFolderDocuments();
    final monitor = _Monitor();
    final coordinator = SourceWatchCoordinator(
      monitor: monitor,
      refresh: _refresh(repository, folderDocuments: documents),
      currentSelection: () => readme,
      quietPeriod: Duration.zero,
    );
    addTearDown(() async {
      await coordinator.dispose();
      await monitor.close();
    });
    coordinator.watchFolder(folder);
    final emitted = <SourceSyncEvent>[];
    final subscription = coordinator.events.listen(emitted.add);
    addTearDown(subscription.cancel);

    monitor.folder.add(FolderDocumentsInvalidated(folder, const ['README.md']));
    await documents.started.future;
    coordinator.watchFolder(folder);
    documents.release.complete();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(repository.library!.find(readme)?.content, '# Before');
    expect(emitted, isEmpty);
  });

  test(
    'an event arriving during a refresh is reread after that refresh',
    () async {
      final repository = _Repository(folderLibrary());
      final documents = _SequencedFolderDocuments();
      final monitor = _Monitor();
      final coordinator = SourceWatchCoordinator(
        monitor: monitor,
        refresh: _refresh(repository, folderDocuments: documents),
        currentSelection: () => readme,
        quietPeriod: const Duration(milliseconds: 5),
      );
      addTearDown(() async {
        await coordinator.dispose();
        await monitor.close();
      });
      coordinator.watchFolder(folder);
      final finalUpdate = coordinator.events
          .where((event) => event is SourceSynchronized)
          .cast<SourceSynchronized>()
          .firstWhere(
            (event) => event.result.library.find(readme)?.content == '# Final',
          );

      monitor.folder.add(
        FolderDocumentsInvalidated(folder, const ['README.md']),
      );
      await documents.started.future;
      monitor.folder.add(
        FolderDocumentsInvalidated(folder, const ['README.md']),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      documents.release.complete();
      await finalUpdate.timeout(const Duration(seconds: 1));

      expect(documents.calls, 2);
      expect(repository.library!.find(readme)?.content, '# Final');
    },
  );
}

RefreshSource _refresh(
  _Repository repository, {
  FolderDocumentScanner? folderDocuments,
  _MarkdownScanner? markdowns,
  _Workspace? workspace,
}) => RefreshSource(
  folders: _FolderScanner(),
  folderDocuments: folderDocuments ?? _FolderDocuments({}),
  markdowns: markdowns ?? _MarkdownScanner({}),
  repository: repository,
  mutations: LibraryMutationQueue(),
  workspace: workspace,
);

final class _Repository implements LibraryRepository {
  Library? library;
  _Repository(this.library);

  @override
  Future<Library?> current() async => library;

  @override
  Future<void> save(Library library) async => this.library = library;
}

final class _FolderScanner implements FolderScanner {
  @override
  Future<ScannedFolder> scan(FolderRef ref) => throw FolderUnavailable(ref);
}

final class _FolderDocuments implements FolderDocumentScanner {
  final Map<String, ScannedFolderDocument?> documents;
  final calls = <String>[];

  _FolderDocuments(this.documents);

  @override
  Future<ScannedFolderDocument?> scanDocument(
    FolderRef folder,
    String relativePath,
  ) async {
    calls.add(relativePath);
    return documents[relativePath];
  }
}

final class _BlockingFolderDocuments implements FolderDocumentScanner {
  final started = Completer<void>();
  final release = Completer<void>();

  @override
  Future<ScannedFolderDocument?> scanDocument(
    FolderRef folder,
    String relativePath,
  ) async {
    started.complete();
    await release.future;
    return const ScannedFolderDocument(
      relativePath: 'README.md',
      content: '# Obsolete',
      sourceId: null,
    );
  }
}

final class _SequencedFolderDocuments implements FolderDocumentScanner {
  final started = Completer<void>();
  final release = Completer<void>();
  var calls = 0;

  @override
  Future<ScannedFolderDocument?> scanDocument(
    FolderRef folder,
    String relativePath,
  ) async {
    calls++;
    if (calls == 1) {
      started.complete();
      await release.future;
      return const ScannedFolderDocument(
        relativePath: 'README.md',
        content: '# First',
        sourceId: null,
      );
    }
    return const ScannedFolderDocument(
      relativePath: 'README.md',
      content: '# Final',
      sourceId: null,
    );
  }
}

final class _MarkdownScanner implements MarkdownScanner {
  final Map<String, ScannedMarkdown> markdowns;
  _MarkdownScanner(this.markdowns);

  @override
  Future<ScannedMarkdown> scan(MarkdownRef ref) async =>
      markdowns[ref.id] ?? (throw MarkdownUnavailable(ref));
}

final class _Workspace implements WorkspaceMutationCommitter {
  DocumentId? active;

  @override
  Future<void> folderAdded(
    FolderRef ref,
    Library library,
    DocumentId? active,
  ) async {}

  @override
  Future<void> markdownAdded(
    MarkdownRef ref,
    Library library,
    DocumentId active, {
    required bool added,
  }) async {}

  @override
  Future<void> libraryChanged(Library library, DocumentId? active) async {
    this.active = active;
  }
}

final class _Monitor implements SourceChangeMonitor {
  final folder = StreamController<SourceChange>.broadcast();

  @override
  Stream<SourceChange> watchFolder(FolderRef folder) => this.folder.stream;

  @override
  Stream<SourceChange> watchMarkdown(MarkdownRef markdown) =>
      const Stream.empty();

  Future<void> close() => folder.close();
}
