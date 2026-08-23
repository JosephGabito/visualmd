// ignore_for_file: prefer_initializing_formals — named parameters describe the composition contract.

import '../../domain/library/document_id.dart';
import '../../domain/library/library.dart';
import '../../domain/library/library_root_id.dart';
import '../library_mutation_queue.dart';
import '../ports/library_repository.dart';
import '../ports/workspace_mutation_committer.dart';

/// Reorders one top-level folder while preserving every nested shelf order.
final class MoveFolder {
  final LibraryRepository _repository;
  final LibraryMutationQueue _mutations;
  final WorkspaceMutationCommitter? _workspace;

  const MoveFolder({
    required LibraryRepository repository,
    required LibraryMutationQueue mutations,
    WorkspaceMutationCommitter? workspace,
  }) : _repository = repository,
       _mutations = mutations,
       _workspace = workspace;

  Future<Library> execute(
    LibraryRootId id,
    int toIndex, {
    DocumentId? selected,
  }) => _mutations.run(() async {
    final current = await _repository.current() ?? Library.empty();
    final library = current.move(id, toIndex);
    if (!identical(library, current)) {
      await _workspace?.libraryChanged(library, selected);
      await _repository.save(library);
    }
    return library;
  });
}
