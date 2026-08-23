import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/application/library_mutation_queue.dart';
import 'package:visualmd/application/ports/folder_scanner.dart';
import 'package:visualmd/application/ports/library_repository.dart';
import 'package:visualmd/application/ports/markdown_scanner.dart';
import 'package:visualmd/application/ports/workspace_files.dart';
import 'package:visualmd/application/ports/workspace_ids.dart';
import 'package:visualmd/application/ports/workspace_session_repository.dart';
import 'package:visualmd/application/ports/workspace_restoration.dart';
import 'package:visualmd/application/ports/workspace_source_access.dart';
import 'package:visualmd/application/use_cases/open_workspace.dart';
import 'package:visualmd/application/use_cases/create_workspace.dart';
import 'package:visualmd/application/use_cases/reconnect_workspace_source.dart';
import 'package:visualmd/application/use_cases/save_workspace.dart';
import 'package:visualmd/application/use_cases/update_workspace.dart';
import 'package:visualmd/application/workspace_autosave.dart';
import 'package:visualmd/domain/library/document_id.dart';
import 'package:visualmd/domain/library/document_source_id.dart';
import 'package:visualmd/domain/library/library.dart';
import 'package:visualmd/domain/library/library_builder.dart';
import 'package:visualmd/domain/library/library_root_id.dart';
import 'package:visualmd/domain/workspace/workspace.dart';
import 'package:visualmd/domain/workspace/workspace_id.dart';
import 'package:visualmd/domain/workspace/workspace_source.dart';
import 'package:visualmd/domain/workspace/workspace_theme.dart';
import 'package:visualmd/infrastructure/workspace/workspace_json_codec.dart';

void main() {
  const file = WorkspaceFileRef(id: 'workspace-file', name: 'Room.json');
  final folder = WorkspaceSource(
    id: const WorkspaceSourceId('folder'),
    displayName: 'Notes',
    relativePath: 'Notes',
  );
  final markdown = WorkspaceSource(
    id: const WorkspaceSourceId('markdown'),
    displayName: 'plan.md',
    relativePath: 'plan.md',
  );

  Workspace workspace({
    List<WorkspaceSource>? folders,
    List<WorkspaceSource>? markdowns,
    WorkspaceDocument? active,
  }) => Workspace(
    id: const WorkspaceId('workspace'),
    documentRootAbsolutePath: '/work',
    theme: const FixedWorkspaceTheme('paper'),
    folders: folders ?? [folder],
    markdowns: markdowns ?? const [],
    activeDocument: active,
  );

  test('workspace file names carry the public format suffix exactly once', () {
    expect(workspaceFileName('Project'), 'Project.visualmd-workspace.json');
    expect(
      workspaceFileName('Project.json'),
      'Project.visualmd-workspace.json',
    );
    expect(
      workspaceFileName('Project.visualmd-workspace.json'),
      'Project.visualmd-workspace.json',
    );
  });

  test(
    'New Workspace replaces both projections with one unbound room',
    () async {
      final libraries = _Libraries(
        Library(
          roots: [
            LibraryBuilder.buildRoot(
              id: const LibraryRootId('old'),
              name: 'Old',
              files: const [FileEntry('README.md', '# Old')],
            ),
          ],
        ),
      );
      final sessions = _Sessions(
        WorkspaceSession(workspace: workspace(), file: file, dirty: false),
      );
      final files = _Files();
      final mutations = LibraryMutationQueue();

      final created = await CreateWorkspace(
        ids: const _Ids(),
        restoration: _Restoration(libraries, sessions),
        mutations: mutations,
        autosave: _autosave(sessions, files, mutations),
      ).execute(const FixedWorkspaceTheme('midnight'));

      expect(created.workspace.id, const WorkspaceId('workspace-fork'));
      expect(created.workspace.theme, const FixedWorkspaceTheme('midnight'));
      expect(created.file, isNull);
      expect(created.dirty, isTrue);
      expect(libraries.value!.isEmpty, isTrue);
      expect(sessions.value, same(created));
    },
  );

  test(
    'Save asks once for an unbound file and cancellation changes nothing',
    () async {
      final current = WorkspaceSession(
        workspace: workspace(),
        file: null,
        dirty: true,
      );
      final sessions = _Sessions(current);
      final files = _Files()..saveSelection = null;
      final mutations = LibraryMutationQueue();

      final result = await SaveWorkspace(
        sessions: sessions,
        files: files,
        codec: const WorkspaceJsonCodec(),
        mutations: mutations,
        autosave: _autosave(sessions, files, mutations),
      ).execute();

      expect(result, same(current));
      expect(sessions.value, same(current));
      expect(files.writes, isEmpty);
      expect(files.suggestedNames, ['Untitled.visualmd-workspace.json']);
    },
  );

  test('Save As forks identity only after the new file is written', () async {
    final events = <String>[];
    final sessions = _Sessions(
      WorkspaceSession(workspace: workspace(), file: file, dirty: false),
      events,
    );
    final files = _Files(events)
      ..saveSelection = const WorkspaceFileRef(
        id: 'fork',
        name: 'Fork.visualmd-workspace.json',
      );
    final mutations = LibraryMutationQueue();

    final result = await SaveWorkspaceAs(
      sessions: sessions,
      files: files,
      codec: const WorkspaceJsonCodec(),
      ids: const _Ids(),
      mutations: mutations,
      access: _Access(events: events),
      autosave: _autosave(sessions, files, mutations),
    ).execute();

    expect(result!.workspace.id, const WorkspaceId('workspace-fork'));
    expect(result.file!.id, 'fork');
    expect(files.suggestedNames, ['Room.visualmd-workspace.json']);
    expect(events, [
      'bindings:workspace->workspace-fork',
      'write:fork',
      'session:workspace-fork',
    ]);
  });

  test('cancelling Save As resumes a pending save to the old file', () async {
    final sessions = _Sessions(
      WorkspaceSession(workspace: workspace(), file: file, dirty: true),
    );
    final files = _Files()..saveSelection = null;
    final mutations = LibraryMutationQueue();
    final autosave = _autosave(sessions, files, mutations);

    final result = await SaveWorkspaceAs(
      sessions: sessions,
      files: files,
      codec: const WorkspaceJsonCodec(),
      ids: const _Ids(),
      mutations: mutations,
      access: _Access(),
      autosave: autosave,
    ).execute();
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(result!.file, file);
    expect(files.writes.map((write) => write.$1), [file]);
    expect(sessions.value!.dirty, isFalse);
  });

  test('malformed workspace input leaves the open session untouched', () async {
    final oldLibrary = Library(
      roots: [
        LibraryBuilder.buildRoot(
          id: const LibraryRootId('old'),
          name: 'Old',
          files: const [FileEntry('README.md', '# Old')],
        ),
      ],
    );
    final libraries = _Libraries(oldLibrary);
    final oldSession = WorkspaceSession(
      workspace: workspace(),
      file: file,
      dirty: false,
    );
    final sessions = _Sessions(oldSession);
    final files = _Files()
      ..openSelection = file
      ..reads[file.id] = '{broken';

    await expectLater(
      _open(files, libraries, sessions, _Access()).execute(),
      throwsA(isA<WorkspaceFormatException>()),
    );

    expect(libraries.value, same(oldLibrary));
    expect(sessions.value, same(oldSession));
  });

  test(
    'unavailable sources keep their saved slots while others restore',
    () async {
      final missing = WorkspaceSource(
        id: const WorkspaceSourceId('missing'),
        displayName: 'Missing',
        relativePath: 'Missing',
      );
      final source = workspace(folders: [missing, folder]);
      final access = _Access()..missingFolders.add(missing.id);
      final folders = _Folders({
        'folder': const ScannedFolder(
          name: 'Notes',
          files: [FileEntry('README.md', '# Notes')],
        ),
      });
      final libraries = _Libraries(null);
      final sessions = _Sessions(null);

      final opened = await _open(
        _Files(),
        libraries,
        sessions,
        access,
        folders: folders,
      ).restore(source, file);

      expect(opened.library.roots.single.id.value, 'folder');
      expect(opened.session.workspace.folders, [missing, folder]);
      expect(opened.session.unavailableSources, {missing.id});
    },
  );

  test(
    'folder restoration atomically absorbs an active standalone file',
    () async {
      final events = <String>[];
      final physical = DocumentSourceId('/work/Notes/plan.md');
      final source = workspace(
        folders: [folder],
        markdowns: [markdown],
        active: WorkspaceDocument(
          sourceId: markdown.id,
          relativePath: 'plan.md',
        ),
      );
      final files = _Files(events);
      final libraries = _Libraries(null, events);
      final sessions = _Sessions(null, events);

      final opened = await _open(
        files,
        libraries,
        sessions,
        _Access(),
        folders: _Folders({
          'folder': ScannedFolder(
            name: 'Notes',
            files: [FileEntry('plan.md', '# Folder plan', sourceId: physical)],
          ),
        }),
        markdowns: _Markdowns({
          'markdown': ScannedMarkdown(
            name: 'plan.md',
            content: '# Standalone plan',
            sourceId: physical,
          ),
        }),
      ).restore(source, file);

      expect(opened.library.markdowns, isEmpty);
      expect(opened.session.workspace.markdowns, isEmpty);
      expect(
        opened.session.workspace.activeDocument,
        WorkspaceDocument(sourceId: folder.id, relativePath: 'plan.md'),
      );
      expect(
        opened.activeDocument!.id,
        DocumentId(const LibraryRootId('folder'), 'plan.md'),
      );
      expect(events, ['write:workspace-file', 'library', 'session:workspace']);
    },
  );

  test(
    'web upload restoration records absorption as dirty without downloading',
    () async {
      const upload = WorkspaceFileRef(
        id: 'upload',
        name: 'Room.visualmd-workspace.json',
        supportsAutomaticWrites: false,
      );
      final physical = DocumentSourceId('/work/Notes/plan.md');
      final source = workspace(folders: [folder], markdowns: [markdown]);
      final files = _Files();
      final libraries = _Libraries(null);
      final sessions = _Sessions(null);

      final opened = await _open(
        files,
        libraries,
        sessions,
        _Access(),
        folders: _Folders({
          'folder': ScannedFolder(
            name: 'Notes',
            files: [FileEntry('plan.md', '# Plan', sourceId: physical)],
          ),
        }),
        markdowns: _Markdowns({
          'markdown': ScannedMarkdown(
            name: 'plan.md',
            content: '# Plan',
            sourceId: physical,
          ),
        }),
      ).restore(source, upload);

      expect(opened.session.workspace.markdowns, isEmpty);
      expect(opened.session.dirty, isTrue);
      expect(files.writes, isEmpty);
    },
  );

  test(
    'an unexpected scan failure aborts the complete restore transaction',
    () async {
      final oldLibrary = Library.empty();
      final oldSession = WorkspaceSession(
        workspace: workspace(folders: const []),
        file: file,
        dirty: false,
      );
      final libraries = _Libraries(oldLibrary);
      final sessions = _Sessions(oldSession);

      await expectLater(
        _open(
          _Files(),
          libraries,
          sessions,
          _Access(),
          folders: _Folders(const {}, failure: StateError('corrupt read')),
        ).restore(workspace(), file),
        throwsStateError,
      );

      expect(libraries.value, same(oldLibrary));
      expect(sessions.value, same(oldSession));
    },
  );

  test('saving a live mutation does not move an unavailable folder', () async {
    final missing = WorkspaceSource(
      id: const WorkspaceSourceId('missing'),
      displayName: 'Missing',
      relativePath: 'Missing',
    );
    final current = WorkspaceSession(
      workspace: workspace(folders: [missing, folder]),
      file: file,
      dirty: false,
      unavailableSources: {missing.id},
    );
    final sessions = _Sessions(current);
    final files = _Files();
    final mutations = LibraryMutationQueue();
    final updater = UpdateWorkspace(
      sessions: sessions,
      access: _Access(),
      files: files,
      codec: const WorkspaceJsonCodec(),
      mutations: mutations,
      autosave: _autosave(sessions, files, mutations),
    );
    final live = Library(
      roots: [
        LibraryBuilder.buildRoot(
          id: const LibraryRootId('folder'),
          name: 'Notes',
          files: const [FileEntry('README.md', '# Notes')],
        ),
      ],
    );

    await updater.libraryChanged(live, null);

    expect(sessions.value!.workspace.folders, [missing, folder]);
  });

  test(
    'Save flushes the latest deferred workspace change exactly once',
    () async {
      final sessions = _Sessions(
        WorkspaceSession(workspace: workspace(), file: file, dirty: false),
      );
      final files = _Files();
      final mutations = LibraryMutationQueue();
      final autosave = WorkspaceAutosave(
        sessions: sessions,
        files: files,
        codec: const WorkspaceJsonCodec(),
        mutations: mutations,
        delay: const Duration(hours: 1),
      );
      final updater = UpdateWorkspace(
        sessions: sessions,
        access: _Access(),
        files: files,
        codec: const WorkspaceJsonCodec(),
        mutations: mutations,
        autosave: autosave,
      );
      final library = Library(
        roots: [
          LibraryBuilder.buildRoot(
            id: const LibraryRootId('folder'),
            name: 'Notes',
            files: const [
              FileEntry('README.md', '# Notes'),
              FileEntry('later.md', '# Later'),
            ],
          ),
        ],
      );

      await updater.rememberActive(
        library,
        DocumentId(const LibraryRootId('folder'), 'later.md'),
      );
      expect(sessions.value!.dirty, isTrue);

      await SaveWorkspace(
        sessions: sessions,
        files: files,
        codec: const WorkspaceJsonCodec(),
        mutations: mutations,
        autosave: autosave,
      ).execute();

      expect(files.writes, hasLength(1));
      expect(sessions.value!.dirty, isFalse);
      expect(
        sessions.value!.workspace.activeDocument!.relativePath,
        'later.md',
      );
    },
  );

  test('download-only web files stay dirty until an explicit Save', () async {
    const download = WorkspaceFileRef(
      id: 'download',
      name: 'Room.visualmd-workspace.json',
      supportsAutomaticWrites: false,
    );
    final sessions = _Sessions(
      WorkspaceSession(workspace: workspace(), file: download, dirty: false),
    );
    final files = _Files();
    final mutations = LibraryMutationQueue();
    final autosave = _autosave(sessions, files, mutations);
    final updater = UpdateWorkspace(
      sessions: sessions,
      access: _Access(),
      files: files,
      codec: const WorkspaceJsonCodec(),
      mutations: mutations,
      autosave: autosave,
    );
    final library = Library(
      roots: [
        LibraryBuilder.buildRoot(
          id: const LibraryRootId('folder'),
          name: 'Notes',
          files: const [FileEntry('README.md', '# Notes')],
        ),
      ],
    );

    await updater.rememberActive(
      library,
      DocumentId(const LibraryRootId('folder'), 'README.md'),
    );
    await autosave.flush();

    expect(files.writes, isEmpty);
    expect(sessions.value!.dirty, isTrue);

    await SaveWorkspace(
      sessions: sessions,
      files: files,
      codec: const WorkspaceJsonCodec(),
      mutations: mutations,
      autosave: autosave,
    ).execute();

    expect(files.writes, hasLength(1));
    expect(sessions.value!.dirty, isFalse);
  });

  test(
    'background autosave reports write failure and leaves state dirty',
    () async {
      final sessions = _Sessions(
        WorkspaceSession(workspace: workspace(), file: file, dirty: true),
      );
      final files = _Files()..writeFailure = StateError('disk full');
      final autosave = WorkspaceAutosave(
        sessions: sessions,
        files: files,
        codec: const WorkspaceJsonCodec(),
        mutations: LibraryMutationQueue(),
        delay: Duration.zero,
      );
      final failure = autosave.failures.first;

      autosave.schedule();

      expect(await failure, isA<StateError>());
      expect(sessions.value!.dirty, isTrue);
    },
  );

  test(
    'reconnection projects a missing source back into its saved slot',
    () async {
      final first = WorkspaceSource(
        id: const WorkspaceSourceId('first'),
        displayName: 'First',
        relativePath: 'First',
      );
      final missing = WorkspaceSource(
        id: const WorkspaceSourceId('missing'),
        displayName: 'Missing',
        relativePath: 'Missing',
      );
      final sessions = _Sessions(
        WorkspaceSession(
          workspace: workspace(folders: [first, missing, folder]),
          file: file,
          dirty: false,
          unavailableSources: {missing.id},
        ),
      );
      final access = _Access()
        ..reconnectedFolder = const FolderRef(id: 'missing', name: 'Missing');

      final result = await ReconnectWorkspaceSource(
        sessions: sessions,
        access: access,
      ).execute(missing.id);

      expect(result, isA<ReconnectedFolder>());
      expect((result! as ReconnectedFolder).insertionIndex, 1);
    },
  );

  test(
    'a source directly beneath a Windows drive keeps the drive as root',
    () async {
      final sessions = _Sessions(
        WorkspaceSession(
          workspace: Workspace(
            id: const WorkspaceId('workspace'),
            documentRootAbsolutePath: null,
            theme: const FixedWorkspaceTheme('paper'),
          ),
          file: null,
          dirty: true,
        ),
      );
      final files = _Files();
      final mutations = LibraryMutationQueue();
      final access = _Access()..folderAbsolutePath = r'C:\Notes';
      final updater = UpdateWorkspace(
        sessions: sessions,
        access: access,
        files: files,
        codec: const WorkspaceJsonCodec(),
        mutations: mutations,
        autosave: _autosave(sessions, files, mutations),
      );
      final library = Library(
        roots: [
          LibraryBuilder.buildRoot(
            id: const LibraryRootId('folder'),
            name: 'Notes',
            files: const [FileEntry('README.md', '# Notes')],
          ),
        ],
      );

      await updater.folderAdded(
        const FolderRef(id: 'folder', name: 'Notes'),
        library,
        null,
      );

      expect(sessions.value!.workspace.documentRootAbsolutePath, 'C:/');
      expect(sessions.value!.workspace.folders.single.relativePath, 'Notes');
    },
  );
}

OpenWorkspace _open(
  _Files files,
  _Libraries libraries,
  _Sessions sessions,
  _Access access, {
  _Folders? folders,
  _Markdowns? markdowns,
}) {
  final mutations = LibraryMutationQueue();
  return OpenWorkspace(
    files: files,
    codec: const WorkspaceJsonCodec(),
    access: access,
    folders: folders ?? _Folders(const {}),
    markdowns: markdowns ?? _Markdowns(const {}),
    restoration: _Restoration(libraries, sessions),
    mutations: mutations,
    autosave: WorkspaceAutosave(
      sessions: sessions,
      files: files,
      codec: const WorkspaceJsonCodec(),
      mutations: mutations,
      delay: Duration.zero,
    ),
  );
}

final class _Files implements WorkspaceFiles {
  final List<String> events;
  final reads = <String, String>{};
  final writes = <(WorkspaceFileRef, String)>[];
  final suggestedNames = <String>[];
  WorkspaceFileRef? openSelection;
  WorkspaceFileRef? saveSelection;
  Object? writeFailure;

  _Files([List<String>? events]) : events = events ?? [];

  @override
  Future<WorkspaceFileRef?> pickOpen() async => openSelection;

  @override
  Future<WorkspaceFileRef?> pickSave({required String suggestedName}) async {
    suggestedNames.add(suggestedName);
    return saveSelection;
  }

  @override
  Future<String> read(WorkspaceFileRef file) async => reads[file.id]!;

  @override
  Future<void> write(WorkspaceFileRef file, String contents) async {
    if (writeFailure case final failure?) throw failure;
    events.add('write:${file.id}');
    writes.add((file, contents));
  }
}

final class _Sessions implements WorkspaceSessionRepository {
  WorkspaceSession? value;
  final List<String> events;

  _Sessions(this.value, [List<String>? events]) : events = events ?? [];

  @override
  Future<WorkspaceSession?> current() async => value;

  @override
  Future<void> save(WorkspaceSession session) async {
    events.add('session:${session.workspace.id.value}');
    value = session;
  }
}

final class _Libraries implements LibraryRepository {
  Library? value;
  final List<String> events;

  _Libraries(this.value, [List<String>? events]) : events = events ?? [];

  @override
  Future<Library?> current() async => value;

  @override
  Future<void> save(Library library) async {
    events.add('library');
    value = library;
  }
}

final class _Restoration implements WorkspaceRestoration {
  final _Libraries libraries;
  final _Sessions sessions;

  const _Restoration(this.libraries, this.sessions);

  @override
  void replace(Library library, WorkspaceSession session) {
    libraries.events.add('library');
    libraries.value = library;
    sessions.events.add('session:${session.workspace.id.value}');
    sessions.value = session;
  }
}

final class _Ids implements WorkspaceIds {
  const _Ids();

  @override
  WorkspaceId workspaceId() => const WorkspaceId('workspace-fork');

  @override
  WorkspaceSourceId sourceId() => const WorkspaceSourceId('source-fork');
}

final class _Access implements WorkspaceSourceAccess {
  final List<String> events;
  final missingFolders = <WorkspaceSourceId>{};
  final missingMarkdowns = <WorkspaceSourceId>{};
  FolderRef? reconnectedFolder;
  MarkdownRef? reconnectedMarkdown;
  String? folderAbsolutePath;

  _Access({List<String>? events}) : events = events ?? [];

  @override
  Future<void> forkBindings(
    WorkspaceId from,
    WorkspaceId to,
    Iterable<WorkspaceSourceId> sources,
  ) async {
    events.add('bindings:${from.value}->${to.value}');
  }

  @override
  Future<FolderRef> restoreFolder(
    Workspace workspace,
    WorkspaceSource source,
  ) async {
    if (missingFolders.contains(source.id)) {
      throw WorkspaceSourceUnavailable(source);
    }
    return FolderRef(id: source.id.value, name: source.displayName);
  }

  @override
  Future<MarkdownRef> restoreMarkdown(
    Workspace workspace,
    WorkspaceSource source,
  ) async {
    if (missingMarkdowns.contains(source.id)) {
      throw WorkspaceSourceUnavailable(source);
    }
    return MarkdownRef(id: source.id.value, name: source.displayName);
  }

  @override
  Future<WorkspaceSourceLocation> locateFolder(FolderRef ref) async =>
      WorkspaceSourceLocation(
        displayName: ref.name,
        absolutePath: folderAbsolutePath ?? '/work/${ref.name}',
      );

  @override
  Future<WorkspaceSourceLocation> locateMarkdown(MarkdownRef ref) async =>
      WorkspaceSourceLocation(
        displayName: ref.name,
        absolutePath: '/work/${ref.name}',
      );

  @override
  Future<void> bindFolder(
    WorkspaceId workspaceId,
    WorkspaceSourceId sourceId,
    FolderRef ref,
  ) async {}

  @override
  Future<void> bindMarkdown(
    WorkspaceId workspaceId,
    WorkspaceSourceId sourceId,
    MarkdownRef ref,
  ) async {}

  @override
  Future<FolderRef?> reconnectFolder(
    Workspace workspace,
    WorkspaceSource source,
  ) async => reconnectedFolder;

  @override
  Future<MarkdownRef?> reconnectMarkdown(
    Workspace workspace,
    WorkspaceSource source,
  ) async => reconnectedMarkdown;
}

final class _Folders implements FolderScanner {
  final Map<String, ScannedFolder> values;
  final Object? failure;

  _Folders(this.values, {this.failure});

  @override
  Future<ScannedFolder> scan(FolderRef ref) async {
    if (failure case final error?) throw error;
    return values[ref.id] ?? (throw FolderUnavailable(ref));
  }
}

final class _Markdowns implements MarkdownScanner {
  final Map<String, ScannedMarkdown> values;

  _Markdowns(this.values);

  @override
  Future<ScannedMarkdown> scan(MarkdownRef ref) async =>
      values[ref.id] ?? (throw MarkdownUnavailable(ref));
}

WorkspaceAutosave _autosave(
  _Sessions sessions,
  _Files files,
  LibraryMutationQueue mutations,
) => WorkspaceAutosave(
  sessions: sessions,
  files: files,
  codec: const WorkspaceJsonCodec(),
  mutations: mutations,
  delay: Duration.zero,
);
