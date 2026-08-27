// ignore_for_file: prefer_initializing_formals — named parameters describe the composition contract.

import '../../domain/library/document.dart';
import '../../domain/library/document_id.dart';
import '../../domain/library/library.dart';
import '../../domain/library/library_builder.dart';
import '../../domain/library/library_root.dart';
import '../../domain/library/library_root_id.dart';
import '../library_mutation_queue.dart';
import '../ports/folder_scanner.dart';
import '../ports/library_repository.dart';
import '../ports/workspace_mutation_committer.dart';

final class AddedFolder {
  final Library library;
  final LibraryRoot root;
  final bool refreshed;
  final Document? adaptedDocument;
  final Document? nextDocument;
  final DeferredFolderTitles? deferredTitles;

  const AddedFolder({
    required this.library,
    required this.root,
    required this.refreshed,
    required this.adaptedDocument,
    required this.nextDocument,
    this.deferredTitles,
  });

  Document? get openingDocument => root.openingDocument;
}

/// Adds a scanned folder to the session, or refreshes it in place by identity.
final class AddFolder {
  final FolderScanner _scanner;
  final FolderMetadataScanner? _metadataScanner;
  final LibraryRepository _repository;
  final LibraryMutationQueue _mutations;
  final WorkspaceMutationCommitter? _workspace;

  const AddFolder({
    required FolderScanner scanner,
    FolderMetadataScanner? metadataScanner,
    required LibraryRepository repository,
    required LibraryMutationQueue mutations,
    WorkspaceMutationCommitter? workspace,
  }) : _scanner = scanner,
       _metadataScanner = metadataScanner,
       _repository = repository,
       _mutations = mutations,
       _workspace = workspace;

  Future<AddedFolder> execute(
    FolderRef ref, {
    DocumentId? selected,
    int? atIndex,
  }) => _mutations.run(() async {
    final scanned =
        await (_metadataScanner?.scanMetadata(ref) ?? _scanner.scan(ref));
    final id = LibraryRootId(ref.id);
    final current = await _repository.current() ?? Library.empty();
    final refreshed = current.rootById(id) != null;
    final root = LibraryBuilder.buildRoot(
      id: id,
      name: scanned.name,
      files: scanned.files,
    );
    final documentsBySource = {
      for (final document in root.documents)
        if (document.sourceId != null) document.sourceId!: document,
    };
    Document? adaptedDocument;
    final retainedMarkdowns = <Document>[];
    for (final markdown in current.markdowns) {
      final adapted = markdown.sourceId == null
          ? null
          : documentsBySource[markdown.sourceId];
      if (adapted == null) {
        retainedMarkdowns.add(markdown);
      } else {
        adaptedDocument ??= adapted;
      }
    }
    final base = retainedMarkdowns.length == current.markdowns.length
        ? current
        : Library(roots: current.roots, markdowns: retainedMarkdowns);
    final appended = base.addOrReplace(root);
    final library = !refreshed && atIndex != null
        ? appended.move(id, atIndex)
        : appended;
    final next =
        adaptedDocument ??
        (!refreshed
            ? root.openingDocument
            : selected?.rootId == id
            ? library.find(selected!) ?? root.openingDocument
            : selected == null
            ? null
            : library.find(selected));
    await _workspace?.folderAdded(ref, library, next?.id);
    await _repository.save(library);
    return AddedFolder(
      library: library,
      root: root,
      refreshed: refreshed,
      adaptedDocument: adaptedDocument,
      nextDocument: next,
      deferredTitles: scanned.titlesDeferred
          ? DeferredFolderTitles(ref, scanned)
          : null,
    );
  });
}
