// ignore_for_file: prefer_initializing_formals — named parameters describe the composition contract.

import '../../domain/library/document.dart';
import '../../domain/library/document_id.dart';
import '../../domain/library/document_source_id.dart';
import '../../domain/library/library.dart';
import '../../domain/library/library_builder.dart';
import '../../domain/library/library_root.dart';
import '../../domain/library/library_root_id.dart';
import '../../domain/reading/document_outline.dart';
import '../../domain/workspace/workspace.dart';
import '../../domain/workspace/workspace_id.dart';
import '../library_mutation_queue.dart';
import '../workspace_autosave.dart';
import '../ports/folder_scanner.dart';
import '../ports/markdown_scanner.dart';
import '../ports/workspace_codec.dart';
import '../ports/workspace_files.dart';
import '../ports/workspace_session_repository.dart';
import '../ports/workspace_restoration.dart';
import '../ports/workspace_source_access.dart';

final class OpenedWorkspace {
  final WorkspaceSession session;
  final Library library;
  final Document? activeDocument;
  final List<FolderRef> folderRefs;
  final List<MarkdownRef> markdownRefs;
  final List<DeferredFolderTitles> deferredTitles;

  const OpenedWorkspace({
    required this.session,
    required this.library,
    required this.activeDocument,
    required this.folderRefs,
    required this.markdownRefs,
    this.deferredTitles = const [],
  });
}

/// Opens a workspace only after its entire restorable projection is ready.
final class OpenWorkspace {
  final WorkspaceFiles _files;
  final WorkspaceCodec _codec;
  final WorkspaceSourceAccess _access;
  final FolderScanner _folders;
  final FolderMetadataScanner? _metadataFolders;
  final MarkdownScanner _markdowns;
  final WorkspaceRestoration _restoration;
  final LibraryMutationQueue _mutations;
  final WorkspaceAutosave _autosave;

  const OpenWorkspace({
    required WorkspaceFiles files,
    required WorkspaceCodec codec,
    required WorkspaceSourceAccess access,
    required FolderScanner folders,
    FolderMetadataScanner? metadataFolders,
    required MarkdownScanner markdowns,
    required WorkspaceRestoration restoration,
    required LibraryMutationQueue mutations,
    required WorkspaceAutosave autosave,
  }) : _files = files,
       _codec = codec,
       _access = access,
       _folders = folders,
       _metadataFolders = metadataFolders,
       _markdowns = markdowns,
       _restoration = restoration,
       _mutations = mutations,
       _autosave = autosave;

  Future<OpenedWorkspace?> execute() async {
    await _autosave.flush();
    final file = await _files.pickOpen();
    if (file == null) return null;
    final source = await _files.read(file);
    final workspace = _codec.decode(source);
    return restore(workspace, file);
  }

  Future<OpenedWorkspace> restore(
    Workspace workspace,
    WorkspaceFileRef? file, {
    bool preserveUnresolvedActive = false,
  }) => _mutations.run(() async {
    final roots = <LibraryRoot>[];
    final folderRefs = <FolderRef>[];
    final markdownRefs = <MarkdownRef>[];
    final deferredTitles = <DeferredFolderTitles>[];
    final physicalDocuments = <DocumentSourceId, Document>{};
    final unavailable = <WorkspaceSourceId>{};

    for (final source in workspace.folders) {
      try {
        final ref = await _access.restoreFolder(workspace, source);
        final scanned =
            await (_metadataFolders?.scanMetadata(ref) ?? _folders.scan(ref));
        if (scanned.titlesDeferred) {
          deferredTitles.add(DeferredFolderTitles(ref, scanned));
        }
        final root = LibraryBuilder.buildRoot(
          id: LibraryRootId(source.id.value),
          name: scanned.name,
          files: scanned.files,
        );
        roots.add(root);
        folderRefs.add(ref);
        for (final document in root.documents) {
          final physical = document.sourceId;
          if (physical != null) physicalDocuments[physical] = document;
        }
      } on WorkspaceSourceUnavailable {
        unavailable.add(source.id);
      } on FolderUnavailable {
        unavailable.add(source.id);
      }
    }

    var restored = workspace;
    final standaloneDocuments = <Document>[];
    final retainedMarkdowns = [...workspace.markdowns];
    var active = workspace.activeDocument;
    for (final source in workspace.markdowns) {
      try {
        final ref = await _access.restoreMarkdown(workspace, source);
        final scanned = await _markdowns.scan(ref);
        final absorbed = scanned.sourceId == null
            ? null
            : physicalDocuments[scanned.sourceId];
        if (absorbed != null) {
          retainedMarkdowns.removeWhere(
            (candidate) => candidate.id == source.id,
          );
          if (active?.sourceId == source.id) {
            active = WorkspaceDocument(
              sourceId: WorkspaceSourceId(absorbed.id.rootId.value),
              relativePath: absorbed.id.path,
            );
          }
          continue;
        }
        standaloneDocuments.add(
          Document(
            id: DocumentId(
              LibraryRootId('standalone-markdown:${source.id.value}'),
              scanned.name,
            ),
            sourceId: scanned.sourceId,
            title: DocumentOutline.parse(scanned.content).title,
          ),
        );
        markdownRefs.add(ref);
      } on WorkspaceSourceUnavailable {
        unavailable.add(source.id);
      } on MarkdownUnavailable {
        unavailable.add(source.id);
      }
    }
    restored = restored.copyWith(
      markdowns: retainedMarkdowns,
      activeDocument: active,
      clearActiveDocument: active == null,
    );

    final library = Library(roots: roots, markdowns: standaloneDocuments);
    final selected = _resolveActive(restored.activeDocument, library);
    final opening = selected ?? library.openingDocument;
    if (restored.activeDocument != null &&
        selected == null &&
        opening != null &&
        !preserveUnresolvedActive) {
      restored = restored.copyWith(activeDocument: _addressOf(opening.id));
    }

    // Absorption is part of opening the workspace, so the normalized document
    // reaches disk before either in-memory repository is replaced.
    final normalized = retainedMarkdowns.length != workspace.markdowns.length;
    if (normalized && file != null && file.supportsAutomaticWrites) {
      await _files.write(file, _codec.encode(restored));
    }
    final session = WorkspaceSession(
      workspace: restored,
      file: file,
      dirty: file == null || (normalized && !file.supportsAutomaticWrites),
      unavailableSources: unavailable,
    );
    await _restoration.replace(library, session);
    return OpenedWorkspace(
      session: session,
      library: library,
      activeDocument: opening,
      folderRefs: List.unmodifiable(folderRefs),
      markdownRefs: List.unmodifiable(markdownRefs),
      deferredTitles: List.unmodifiable(deferredTitles),
    );
  });
}

Document? _resolveActive(WorkspaceDocument? active, Library library) {
  if (active == null) return null;
  final folder = library.rootById(LibraryRootId(active.sourceId.value));
  if (folder != null) {
    return folder.find(DocumentId(folder.id, active.relativePath));
  }
  return library.find(
    DocumentId(
      LibraryRootId('standalone-markdown:${active.sourceId.value}'),
      active.relativePath,
    ),
  );
}

WorkspaceDocument _addressOf(DocumentId id) {
  const prefix = 'standalone-markdown:';
  final root = id.rootId.value;
  return WorkspaceDocument(
    sourceId: WorkspaceSourceId(
      root.startsWith(prefix) ? root.substring(prefix.length) : root,
    ),
    relativePath: id.path,
  );
}
