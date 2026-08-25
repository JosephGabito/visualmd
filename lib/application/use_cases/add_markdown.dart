// ignore_for_file: prefer_initializing_formals — named parameters describe the composition contract.

import '../../domain/library/document.dart';
import '../../domain/library/document_id.dart';
import '../../domain/library/library.dart';
import '../../domain/library/library_root_id.dart';
import '../../domain/reading/document_outline.dart';
import '../library_mutation_queue.dart';
import '../ports/library_repository.dart';
import '../ports/markdown_scanner.dart';
import '../ports/workspace_mutation_committer.dart';

final class AddedMarkdown {
  final Library library;
  final Document document;
  final LibraryRootId? containingRoot;
  final bool added;

  const AddedMarkdown({
    required this.library,
    required this.document,
    required this.containingRoot,
    required this.added,
  });
}

/// Adds one standalone markdown, or resolves it to the same physical document
/// already present in the session.
final class AddMarkdown {
  final MarkdownScanner _scanner;
  final LibraryRepository _repository;
  final LibraryMutationQueue _mutations;
  final WorkspaceMutationCommitter? _workspace;

  const AddMarkdown({
    required MarkdownScanner scanner,
    required LibraryRepository repository,
    required LibraryMutationQueue mutations,
    WorkspaceMutationCommitter? workspace,
  }) : _scanner = scanner,
       _repository = repository,
       _mutations = mutations,
       _workspace = workspace;

  Future<AddedMarkdown> execute(
    MarkdownRef ref, {
    int? atIndex,
  }) => _mutations.run(() async {
    final scanned = await _scanner.scan(ref);
    final current = await _repository.current() ?? Library.empty();
    final id = DocumentId(
      LibraryRootId('standalone-markdown:${ref.id}'),
      scanned.name,
    );
    final existing = scanned.sourceId == null
        ? current.find(id)
        : current.findBySource(scanned.sourceId!);
    final title = DocumentOutline.parse(scanned.content).title;
    if (existing != null) {
      final replacement =
          existing.indexedTitle == title &&
              existing.sourceId == scanned.sourceId
          ? existing
          : Document(id: existing.id, sourceId: scanned.sourceId, title: title);
      final library = identical(replacement, existing)
          ? current
          : current.replaceDocument(replacement);
      await _workspace?.markdownAdded(
        ref,
        library,
        replacement.id,
        added: false,
      );
      if (!identical(library, current)) await _repository.save(library);
      return AddedMarkdown(
        library: library,
        document: replacement,
        containingRoot: library.rootById(replacement.id.rootId)?.id,
        added: false,
      );
    }

    final document = Document(id: id, sourceId: scanned.sourceId, title: title);
    final library = current.addOrReplaceMarkdown(document, atIndex: atIndex);
    await _workspace?.markdownAdded(ref, library, document.id, added: true);
    await _repository.save(library);
    return AddedMarkdown(
      library: library,
      document: document,
      containingRoot: null,
      added: true,
    );
  });
}
