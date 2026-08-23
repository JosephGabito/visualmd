// ignore_for_file: prefer_initializing_formals — named parameters describe the composition contract.

import '../../domain/library/document.dart';
import '../../domain/library/document_id.dart';
import '../../domain/library/library.dart';
import '../../domain/library/library_root_id.dart';
import '../library_mutation_queue.dart';
import '../ports/library_repository.dart';
import '../ports/workspace_mutation_committer.dart';

final class RemovedFolder {
  final Library library;
  final Document? nextDocument;

  const RemovedFolder({required this.library, required this.nextDocument});
}

/// Removes one session root without touching the folder on disk.
final class RemoveFolder {
  final LibraryRepository _repository;
  final LibraryMutationQueue _mutations;
  final WorkspaceMutationCommitter? _workspace;

  const RemoveFolder({
    required LibraryRepository repository,
    required LibraryMutationQueue mutations,
    WorkspaceMutationCommitter? workspace,
  }) : _repository = repository,
       _mutations = mutations,
       _workspace = workspace;

  Future<RemovedFolder> execute(LibraryRootId id, {DocumentId? selected}) =>
      _mutations.run(() async {
        final current = await _repository.current() ?? Library.empty();
        final removedIndex = current.roots.indexWhere((root) => root.id == id);
        if (removedIndex < 0) {
          return RemovedFolder(library: current, nextDocument: null);
        }

        final library = current.remove(id);
        Document? next;
        if (selected?.rootId == id && library.roots.isNotEmpty) {
          // Prefer the root that slid into the removed position, then continue
          // forward before walking backward. Empty roots never strand the
          // reader when another neighboring folder has something to open.
          for (
            var index = removedIndex;
            index < library.roots.length;
            index++
          ) {
            next = library.roots[index].openingDocument;
            if (next != null) break;
          }
          for (
            var index = removedIndex.clamp(0, library.roots.length) - 1;
            next == null && index >= 0;
            index--
          ) {
            next = library.roots[index].openingDocument;
          }
        }
        if (selected?.rootId == id &&
            next == null &&
            library.markdowns.isNotEmpty) {
          next = library.markdowns.first;
        }
        final active = selected?.rootId == id ? next?.id : selected;
        await _workspace?.libraryChanged(library, active);
        await _repository.save(library);
        return RemovedFolder(library: library, nextDocument: next);
      });
}
