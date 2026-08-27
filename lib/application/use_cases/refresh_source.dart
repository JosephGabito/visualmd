// ignore_for_file: prefer_initializing_formals — named parameters describe the composition contract.

import '../../domain/library/document.dart';
import '../../domain/library/document_id.dart';
import '../../domain/library/library.dart';
import '../../domain/library/library_builder.dart';
import '../../domain/library/library_root_id.dart';
import '../../domain/reading/document_outline.dart';
import '../library_mutation_queue.dart';
import '../ports/folder_document_scanner.dart';
import '../ports/folder_scanner.dart';
import '../ports/library_repository.dart';
import '../ports/markdown_scanner.dart';
import '../ports/source_change_monitor.dart';
import '../ports/workspace_mutation_committer.dart';

/// The committed result of rereading one externally changed source.
final class RefreshedSource {
  final Library library;
  final DocumentId? activeDocument;
  final Set<DocumentId> changedDocuments;

  const RefreshedSource({
    required this.library,
    required this.activeDocument,
    this.changedDocuments = const {},
  });

  bool get changed => changedDocuments.isNotEmpty;
}

/// Rereads invalidated source bytes and commits one new library snapshot.
///
/// Platform events carry no content. Reading happens here, in mutation order,
/// so an old event always observes the newest bytes available when it runs.
final class RefreshSource {
  final FolderScanner _folders;
  final FolderDocumentScanner _folderDocuments;
  final MarkdownScanner _markdowns;
  final LibraryRepository _repository;
  final LibraryMutationQueue _mutations;
  final WorkspaceMutationCommitter? _workspace;

  const RefreshSource({
    required FolderScanner folders,
    required FolderDocumentScanner folderDocuments,
    required MarkdownScanner markdowns,
    required LibraryRepository repository,
    required LibraryMutationQueue mutations,
    WorkspaceMutationCommitter? workspace,
  }) : _folders = folders,
       _folderDocuments = folderDocuments,
       _markdowns = markdowns,
       _repository = repository,
       _mutations = mutations,
       _workspace = workspace;

  Future<RefreshedSource> execute(
    SourceChange change, {
    DocumentId? selected,
    bool Function()? isCurrent,
  }) => _mutations.run(() async {
    final current = await _repository.current() ?? Library.empty();
    if (isCurrent != null && !isCurrent()) {
      return RefreshedSource(library: current, activeDocument: selected);
    }
    final refreshed = switch (change) {
      FolderDocumentsInvalidated() => await _refreshDocuments(
        current,
        change,
        selected,
      ),
      FolderRescanRequested() => await _refreshFolder(
        current,
        change.folder,
        selected,
      ),
      MarkdownInvalidated() => await _refreshMarkdown(
        current,
        change.markdown,
        selected,
      ),
      SourceWatchFailed() => RefreshedSource(
        library: current,
        activeDocument: selected,
      ),
    };
    // A source can be removed or rebound while its asynchronous disk read is
    // in flight. The mutation queue prevents overlapping commits; this guard
    // prevents an obsolete watch from committing when its turn resumes.
    if (isCurrent != null && !isCurrent()) {
      return RefreshedSource(library: current, activeDocument: selected);
    }
    if (!refreshed.changed) return refreshed;
    if (refreshed.activeDocument != selected) {
      await _workspace?.libraryChanged(
        refreshed.library,
        refreshed.activeDocument,
      );
    }
    await _repository.save(refreshed.library);
    return refreshed;
  });

  Future<RefreshedSource> _refreshDocuments(
    Library current,
    FolderDocumentsInvalidated change,
    DocumentId? selected,
  ) async {
    final root = current.rootById(LibraryRootId(change.folder.id));
    if (root == null || change.relativePaths.isEmpty) {
      return RefreshedSource(library: current, activeDocument: selected);
    }

    final replacements = <DocumentId, Document?>{};
    final changed = <DocumentId>{};
    for (final rawPath in change.relativePaths) {
      final path = DocumentId(root.id, rawPath).path;
      final scanned = await _folderDocuments.scanDocument(change.folder, path);
      final id = DocumentId(root.id, path);
      if (scanned == null) {
        if (root.find(id) != null) {
          replacements[id] = null;
          changed.add(id);
        }
        continue;
      }
      final next = Document(
        id: id,
        sourceId: scanned.sourceId,
        title: DocumentOutline.titleOf(scanned.content),
      );
      replacements[id] = next;
      changed.add(id);
    }
    if (changed.isEmpty) {
      return RefreshedSource(library: current, activeDocument: selected);
    }
    final nextRoot = root.applyDocumentChanges(replacements);
    final library = current.addOrReplace(nextRoot);
    return RefreshedSource(
      library: library,
      activeDocument: _survivingSelection(library, selected),
      changedDocuments: changed,
    );
  }

  Future<RefreshedSource> _refreshFolder(
    Library current,
    FolderRef ref,
    DocumentId? selected,
  ) async {
    final existing = current.rootById(LibraryRootId(ref.id));
    if (existing == null) {
      return RefreshedSource(library: current, activeDocument: selected);
    }
    final scanned = await _folders.scan(ref);
    final nextRoot = LibraryBuilder.buildRoot(
      id: existing.id,
      name: scanned.name,
      files: scanned.files,
    );
    // A rescan is itself an invalidation. Paths that survive may have new
    // bytes even when their lightweight metadata is unchanged.
    final changed = {
      for (final document in existing.documents) document.id,
      for (final document in nextRoot.documents) document.id,
    };
    if (changed.isEmpty) {
      return RefreshedSource(library: current, activeDocument: selected);
    }
    final library = current.addOrReplace(nextRoot);
    return RefreshedSource(
      library: library,
      activeDocument: _survivingSelection(library, selected),
      changedDocuments: changed,
    );
  }

  Future<RefreshedSource> _refreshMarkdown(
    Library current,
    MarkdownRef ref,
    DocumentId? selected,
  ) async {
    final rootId = LibraryRootId('standalone-markdown:${ref.id}');
    final previous = current.markdowns
        .where((document) => document.id.rootId == rootId)
        .firstOrNull;
    if (previous == null) {
      return RefreshedSource(library: current, activeDocument: selected);
    }
    final scanned = await _markdowns.scan(ref);
    final replacement = Document(
      id: previous.id,
      sourceId: scanned.sourceId,
      title: DocumentOutline.parse(scanned.content).title,
    );
    final library = current.replaceDocument(replacement);
    return RefreshedSource(
      library: library,
      activeDocument: _survivingSelection(library, selected),
      changedDocuments: {previous.id},
    );
  }
}

DocumentId? _survivingSelection(Library library, DocumentId? selected) {
  if (selected == null || library.find(selected) != null) return selected;
  return library.rootById(selected.rootId)?.openingDocument?.id ??
      library.openingDocument?.id;
}
