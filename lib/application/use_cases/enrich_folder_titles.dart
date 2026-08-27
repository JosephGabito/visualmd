// ignore_for_file: prefer_initializing_formals — named parameters describe the composition contract.

import '../../domain/library/document.dart';
import '../../domain/library/document_id.dart';
import '../../domain/library/library.dart';
import '../../domain/library/library_root_id.dart';
import '../library_mutation_queue.dart';
import '../ports/folder_scanner.dart';
import '../ports/library_repository.dart';

final class EnrichedFolderTitles {
  final Library library;
  final Set<DocumentId> documents;

  const EnrichedFolderTitles(this.library, this.documents);
}

/// Applies deferred authored titles without changing folder membership.
final class EnrichFolderTitles {
  final FolderMetadataScanner _scanner;
  final LibraryRepository _repository;
  final LibraryMutationQueue _mutations;

  const EnrichFolderTitles({
    required FolderMetadataScanner scanner,
    required LibraryRepository repository,
    required LibraryMutationQueue mutations,
  }) : _scanner = scanner,
       _repository = repository,
       _mutations = mutations;

  Future<EnrichedFolderTitles?> execute(
    DeferredFolderTitles deferred, {
    bool Function()? isCurrent,
  }) async {
    final enriched = await _scanner.enrichTitles(
      deferred.ref,
      deferred.metadata,
    );
    if (isCurrent != null && !isCurrent()) return null;

    return _mutations.run(() async {
      if (isCurrent != null && !isCurrent()) return null;
      final current = await _repository.current();
      final rootId = LibraryRootId(deferred.ref.id);
      final root = current?.rootById(rootId);
      if (current == null || root == null) return null;

      final replacements = <DocumentId, Document?>{};
      for (final file in enriched.files) {
        final id = DocumentId(rootId, file.path);
        final existing = root.find(id);
        if (existing == null || existing.sourceId != file.sourceId) continue;
        if (existing.indexedTitle == file.title) continue;
        replacements[id] = Document(
          id: id,
          content: existing.loadedContent,
          sourceId: existing.sourceId,
          title: file.title,
        );
      }
      if (replacements.isEmpty) {
        return EnrichedFolderTitles(current, const {});
      }
      final next = current.addOrReplace(
        root.applyDocumentChanges(replacements),
      );
      await _repository.save(next);
      return EnrichedFolderTitles(next, Set.unmodifiable(replacements.keys));
    });
  }
}
