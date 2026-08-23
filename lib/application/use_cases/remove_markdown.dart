// ignore_for_file: prefer_initializing_formals — named parameters describe the composition contract.

import '../../domain/library/document.dart';
import '../../domain/library/document_id.dart';
import '../../domain/library/library.dart';
import '../library_mutation_queue.dart';
import '../ports/library_repository.dart';
import '../ports/workspace_mutation_committer.dart';

final class RemovedMarkdown {
  final Library library;
  final Document? nextDocument;

  const RemovedMarkdown({required this.library, required this.nextDocument});
}

/// Removes one standalone document from the session, never from disk.
final class RemoveMarkdown {
  final LibraryRepository _repository;
  final LibraryMutationQueue _mutations;
  final WorkspaceMutationCommitter? _workspace;

  const RemoveMarkdown({
    required LibraryRepository repository,
    required LibraryMutationQueue mutations,
    WorkspaceMutationCommitter? workspace,
  }) : _repository = repository,
       _mutations = mutations,
       _workspace = workspace;

  Future<RemovedMarkdown> execute(DocumentId id, {DocumentId? selected}) =>
      _mutations.run(() async {
        final current = await _repository.current() ?? Library.empty();
        final removedIndex = current.markdowns.indexWhere(
          (document) => document.id == id,
        );
        if (removedIndex < 0) {
          return RemovedMarkdown(library: current, nextDocument: null);
        }

        final library = current.removeMarkdown(id);
        Document? next;
        if (selected == id) {
          if (library.markdowns.isNotEmpty) {
            // Keep reading near the removed row: first the item that slid into
            // its place, otherwise the preceding standalone document.
            final nextIndex = removedIndex.clamp(
              0,
              library.markdowns.length - 1,
            );
            next = library.markdowns[nextIndex];
          } else {
            next = library.openingDocument;
          }
        }
        await _workspace?.libraryChanged(
          library,
          selected == id ? next?.id : selected,
        );
        await _repository.save(library);
        return RemovedMarkdown(library: library, nextDocument: next);
      });
}
