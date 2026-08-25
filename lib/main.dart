// Composition root: the only place that knows every ring at once.
import 'dart:convert';

import 'package:flutter/material.dart';

import 'api/app.dart';
import 'api/highlighting/shiki_code_highlighter.dart';
import 'api/layout/panel_widths.dart';
import 'api/theme/font_licences.dart';
import 'presentation/theme/reading_scale.dart';
import 'api/reader_controller.dart';
import 'api/reader_source_opener.dart';
import 'presentation/theme/theme_choice.dart';
import 'presentation/theme/theme_registry.dart';
import 'application/library_mutation_queue.dart';
import 'application/document_source_reader.dart';
import 'application/source_watch_coordinator.dart';
import 'application/workspace_autosave.dart';
import 'application/use_cases/add_folder.dart';
import 'application/use_cases/add_markdown.dart';
import 'application/use_cases/create_workspace.dart';
import 'application/use_cases/move_folder.dart';
import 'application/use_cases/open_workspace.dart';
import 'application/use_cases/read_document.dart';
import 'application/use_cases/refresh_source.dart';
import 'application/use_cases/reconnect_workspace_source.dart';
import 'application/use_cases/remove_folder.dart';
import 'application/use_cases/remove_markdown.dart';
import 'application/use_cases/search_documents.dart';
import 'application/use_cases/save_workspace.dart';
import 'application/use_cases/update_workspace.dart';
import 'domain/workspace/workspace_theme.dart';
import 'infrastructure/markdown/markdown_document_parser.dart';
import 'infrastructure/mermaid/mermaid_renderer.dart';
import 'infrastructure/memory/in_memory_library_repository.dart';
import 'infrastructure/memory/in_memory_reader_state.dart';
import 'infrastructure/memory/in_memory_workspace_session_repository.dart';
import 'infrastructure/memory/in_memory_workspace_restoration.dart';
import 'infrastructure/memory/sample_document_image_loader.dart';
import 'infrastructure/memory/sample_folder_scanner.dart';
import 'infrastructure/platform/platform.dart';
import 'infrastructure/platform/platform_command.dart';
import 'infrastructure/routing_folder_scanner.dart';
import 'infrastructure/routing_document_image_loader.dart';
import 'infrastructure/routing_workspace_source_access.dart';
import 'infrastructure/search/literal_document_search.dart';
import 'infrastructure/workspace/random_workspace_ids.dart';
import 'infrastructure/workspace/workspace_json_codec.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerFontLicences();

  // Infrastructure
  final platform = await createPlatformAdapters();
  final codeHighlighter = ShikiCodeHighlighter();
  final mermaidRenderer = createMermaidRenderer();
  final readerState = InMemoryReaderState();
  final repository = InMemoryLibraryRepository(readerState);
  final sessions = InMemoryWorkspaceSessionRepository(readerState);
  final restoration = InMemoryWorkspaceRestoration(readerState);
  const workspaceCodec = WorkspaceJsonCodec();
  final workspaceIds = RandomWorkspaceIds();
  final workspaceAccess = RoutingWorkspaceSourceAccess(
    platform.workspaceSourceAccess,
  );
  final scanner = RoutingFolderScanner([
    SampleFolderScanner(),
    platform.folderScanner,
  ]);
  final imageLoader = RoutingDocumentImageLoader([
    const SampleDocumentImageLoader(),
    platform.documentImageLoader,
  ]);

  // Application
  const parser = MarkdownDocumentParser();
  final mutations = LibraryMutationQueue();
  final workspaceAutosave = WorkspaceAutosave(
    sessions: sessions,
    files: platform.workspaceFiles,
    codec: workspaceCodec,
    mutations: mutations,
  );
  final updateWorkspace = UpdateWorkspace(
    sessions: sessions,
    access: workspaceAccess,
    files: platform.workspaceFiles,
    codec: workspaceCodec,
    mutations: mutations,
    autosave: workspaceAutosave,
  );
  final addFolder = AddFolder(
    scanner: scanner,
    repository: repository,
    mutations: mutations,
    workspace: updateWorkspace,
  );
  final addMarkdown = AddMarkdown(
    scanner: platform.markdownScanner,
    repository: repository,
    mutations: mutations,
    workspace: updateWorkspace,
  );
  final documentSources = DocumentSourceReader(
    folderDocuments: platform.folderDocumentScanner,
    markdowns: platform.markdownScanner,
  );
  final removeFolder = RemoveFolder(
    repository: repository,
    mutations: mutations,
    workspace: updateWorkspace,
  );
  final removeMarkdown = RemoveMarkdown(
    repository: repository,
    mutations: mutations,
    workspace: updateWorkspace,
  );
  final moveFolder = MoveFolder(
    repository: repository,
    mutations: mutations,
    workspace: updateWorkspace,
  );
  final readDocument = ReadDocument(
    repository: repository,
    parser: parser,
    sources: documentSources,
  );
  final searchDocuments = SearchDocuments(
    repository: repository,
    search: LiteralDocumentSearch(parser: parser),
    sources: documentSources,
  );
  final refreshSource = RefreshSource(
    folders: scanner,
    folderDocuments: platform.folderDocumentScanner,
    markdowns: platform.markdownScanner,
    repository: repository,
    mutations: mutations,
    workspace: updateWorkspace,
  );

  // Themes: built-ins plus whatever the reader dropped in the themes folder.
  final themes = ThemeRegistry.fromDocuments(
    await platform.readThemeDocuments(),
  );
  final savedChoice = await platform.readPreference(themePreference);
  final themeChoice = savedChoice == null
      ? null
      : ThemeChoice.fromJson(jsonDecode(savedChoice));
  final readingScale =
      ReadingScale.fromStoredBase(
        await platform.readPreference(textSizePreference),
      ).copyWith(
        marking: ReadingScale.markingFromStored(
          await platform.readPreference(paragraphsPreference),
        ),
      );
  final panelWidths = PanelWidths.fromStored(
    await platform.readPreference(shelfWidthPreference),
    await platform.readPreference(outlineWidthPreference),
  );
  final createWorkspace = CreateWorkspace(
    ids: workspaceIds,
    restoration: restoration,
    mutations: mutations,
    autosave: workspaceAutosave,
  );
  final workspaceSession = await createWorkspace.execute(
    _workspaceTheme(themeChoice ?? themes.systemPair),
  );
  final openWorkspace = OpenWorkspace(
    files: platform.workspaceFiles,
    codec: workspaceCodec,
    access: workspaceAccess,
    folders: scanner,
    markdowns: platform.markdownScanner,
    restoration: restoration,
    mutations: mutations,
    autosave: workspaceAutosave,
  );
  final saveWorkspace = SaveWorkspace(
    sessions: sessions,
    files: platform.workspaceFiles,
    codec: workspaceCodec,
    mutations: mutations,
    autosave: workspaceAutosave,
  );
  final saveWorkspaceAs = SaveWorkspaceAs(
    sessions: sessions,
    files: platform.workspaceFiles,
    codec: workspaceCodec,
    ids: workspaceIds,
    mutations: mutations,
    access: workspaceAccess,
    autosave: workspaceAutosave,
  );
  final reconnectWorkspaceSource = ReconnectWorkspaceSource(
    sessions: sessions,
    access: workspaceAccess,
  );

  // Api
  late final ReaderController controller;
  final sourceChanges = SourceWatchCoordinator(
    monitor: platform.sourceChangeMonitor,
    refresh: refreshSource,
    currentSelection: () => controller.reading?.document.id,
  );
  controller = ReaderController(
    addFolder: addFolder,
    addMarkdown: addMarkdown,
    removeFolder: removeFolder,
    removeMarkdown: removeMarkdown,
    moveFolder: moveFolder,
    readDocument: readDocument,
    searchDocuments: searchDocuments,
    pickFolder: platform.pickFolder,
    pickMarkdown: platform.pickMarkdown,
    createWorkspace: createWorkspace,
    openWorkspace: openWorkspace,
    saveWorkspace: saveWorkspace,
    saveWorkspaceAs: saveWorkspaceAs,
    updateWorkspace: updateWorkspace,
    reconnectWorkspaceSource: reconnectWorkspaceSource,
    currentWorkspace: sessions.current,
    workspaceSession: workspaceSession,
    sampleFolder: SampleFolderScanner.ref,
    themes: themes,
    themeChoice: themeChoice,
    readingScale: readingScale,
    panelWidths: panelWidths,
    sourceChanges: sourceChanges,
    savePreference: platform.writePreference,
  );
  final openReaderSources = switch (platform.readerSourcePicker) {
    final picker? => ReaderSourceOpener(picker, controller),
    null => null,
  };
  platform.folderDrops.listen(controller.addFolder);
  platform.markdownDrops.listen(controller.addMarkdown);
  platform.dragging.listen(controller.setDragging);
  platform.commands.listen((command) {
    switch (command) {
      case PlatformCommand.newWorkspace:
        controller.newWorkspace();
      case PlatformCommand.openWorkspace:
        controller.openWorkspace();
      case PlatformCommand.openReaderSources:
        openReaderSources?.call();
      case PlatformCommand.openSampleLibrary:
        controller.openSampleLibrary();
      case PlatformCommand.saveWorkspace:
        controller.saveWorkspace();
      case PlatformCommand.saveWorkspaceAs:
        controller.saveWorkspaceAs();
      case PlatformCommand.addFolder:
        controller.pickAndAddFolder();
      case PlatformCommand.addMarkdown:
        controller.pickAndAddMarkdown();
    }
  });
  workspaceAutosave.failures.listen(controller.reportWorkspaceAutosaveFailure);

  // Shareable starting points (web: `?open=sample`, `?theme=<id>`;
  // `light` and `dark` name the default pair). Not persisted.
  final options = platform.launchOptions;
  if (options['open'] == 'sample') controller.openSampleLibrary();
  final requested = switch (options['theme']) {
    null => null,
    'light' => themes.systemPair.light,
    'dark' => themes.systemPair.dark,
    final id => id,
  };
  if (requested != null && themes.byId(requested) != null) {
    controller.themeChoice = FixedTheme(requested);
  }
  // `?serif=<family>` sets the reading face for this run only, for judging a
  // face on a real document rather than in a specimen.
  final serif = options['serif'];
  if (serif != null && serif.isNotEmpty) {
    controller.serifOverride = serif;
  }
  if (options['paragraphs'] != null) {
    controller.readingScale = controller.readingScale.copyWith(
      marking: ReadingScale.markingFromStored(options['paragraphs']),
    );
  }

  runApp(
    VisualMdApp(
      controller: controller,
      codeHighlighter: codeHighlighter,
      mermaidRenderer: mermaidRenderer,
      imageLoader: imageLoader,
      openReaderSources: openReaderSources?.call,
      openExternal: platform.openExternal,
      dropRegion: platform.dropRegion,
      topBar: platform.topBar,
      windowDragRegion: platform.windowDragRegion,
      openThemesFolder: platform.openThemesFolder,
    ),
  );
}

WorkspaceTheme _workspaceTheme(ThemeChoice choice) => switch (choice) {
  FixedTheme(:final id) => FixedWorkspaceTheme(id),
  FollowSystem(:final light, :final dark) => SystemWorkspaceTheme(
    lightThemeId: light,
    darkThemeId: dark,
  ),
};
