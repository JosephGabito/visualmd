import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/api/app.dart';
import 'package:visualmd/api/reader_controller.dart';
import 'package:visualmd/api/reader_ui_command.dart';
import 'package:visualmd/api/layout/panel_widths.dart';
import 'package:visualmd/api/theme/library_theme.dart';
import 'package:visualmd/api/widgets/collapsible_panel.dart';
import 'package:visualmd/api/widgets/error_notice.dart';
import 'package:visualmd/api/widgets/outline_panel.dart';
import 'package:visualmd/api/widgets/panel_resize_handle.dart';
import 'package:visualmd/api/widgets/pressable.dart';
import 'package:visualmd/api/widgets/reading_pane.dart';
import 'package:visualmd/api/widgets/search_view.dart';
import 'package:visualmd/api/widgets/shelf_panel.dart';
import 'package:visualmd/api/screens/reader_screen.dart';
import 'package:visualmd/application/ports/folder_scanner.dart';
import 'package:visualmd/application/ports/markdown_scanner.dart';
import 'package:visualmd/application/ports/document_search.dart';
import 'package:visualmd/application/ports/workspace_files.dart';
import 'package:visualmd/application/ports/workspace_source_access.dart';
import 'package:visualmd/application/library_mutation_queue.dart';
import 'package:visualmd/application/workspace_autosave.dart';
import 'package:visualmd/application/use_cases/add_folder.dart';
import 'package:visualmd/application/use_cases/add_markdown.dart';
import 'package:visualmd/application/use_cases/move_folder.dart';
import 'package:visualmd/application/use_cases/open_workspace.dart';
import 'package:visualmd/domain/library/document_id.dart';
import 'package:visualmd/domain/library/document.dart';
import 'package:visualmd/domain/library/library_builder.dart';
import 'package:visualmd/domain/library/library_root_id.dart';
import 'package:visualmd/domain/reading/heading.dart';
import 'package:visualmd/domain/search/search_result.dart';
import 'package:visualmd/domain/workspace/workspace.dart';
import 'package:visualmd/domain/workspace/workspace_id.dart';
import 'package:visualmd/domain/workspace/workspace_source.dart';
import 'package:visualmd/application/use_cases/read_document.dart';
import 'package:visualmd/application/use_cases/remove_folder.dart';
import 'package:visualmd/application/use_cases/remove_markdown.dart';
import 'package:visualmd/application/use_cases/search_documents.dart';
import 'package:visualmd/infrastructure/markdown/markdown_document_parser.dart';
import 'package:visualmd/infrastructure/memory/in_memory_library_repository.dart';
import 'package:visualmd/infrastructure/memory/in_memory_reader_state.dart';
import 'package:visualmd/infrastructure/memory/in_memory_workspace_restoration.dart';
import 'package:visualmd/infrastructure/memory/in_memory_workspace_session_repository.dart';
import 'package:visualmd/infrastructure/memory/sample_document_image_loader.dart';
import 'package:visualmd/infrastructure/search/literal_document_search.dart';
import 'package:visualmd/infrastructure/viewport/quiet_document_viewport_geometry.dart';
import 'package:visualmd/infrastructure/workspace/workspace_json_codec.dart';
import 'package:visualmd/presentation/code/code_highlighter.dart';
import 'package:visualmd/presentation/theme/built_in_themes.dart';
import 'package:visualmd/presentation/shelf/shelf_label_mode.dart';
import 'package:visualmd/presentation/theme/theme_choice.dart';
import 'package:visualmd/presentation/theme/theme_registry.dart';
import 'package:visualmd/application/ports/mermaid_renderer.dart';

const _library = ScannedFolder(
  name: 'notes',
  files: [
    FileEntry(
      'README.md',
      '# Notes\n\n## First\n\ntext\n\n## Second\n\nmore\n',
    ),
    FileEntry('other.md', '# Other\n'),
    FileEntry('links.md', '''
# Link routes

[Jump to the second repeated heading](#repeated-heading-1).

## Repeated heading

This first section carries enough reading text to move the next target below
the initial viewport. A fragment should identify a heading by its generated
anchor rather than by whichever visible title happens to occur first.

The same title can appear more than once in a real handbook. Its words remain
the same while the document's anchor counter gives each occurrence one stable
destination for the lifetime of this reading.

Readers should arrive without a page reload, a document replacement, or a
surprise handoff to the operating system. This is navigation inside the open
document, so the current library and reading context remain untouched.

One more paragraph establishes enough distance for the animation to be
observable in a compact test viewport while remaining ordinary prose.

## Repeated heading

The duplicate target has the generated anchor `repeated-heading-1`.

Content after the target gives `ensureVisible` enough scroll extent to align
the heading with the reading viewport instead of stopping at the document's
bottom edge.

A final paragraph keeps that geometry deterministic across bundled reading
faces and text metrics.
'''),
  ],
);

final class _Scanner implements FolderScanner {
  @override
  Future<ScannedFolder> scan(FolderRef ref) async => _library;
}

final class _MarkdownScanner implements MarkdownScanner {
  @override
  Future<ScannedMarkdown> scan(MarkdownRef ref) =>
      throw MarkdownUnavailable(ref);
}

final class _RecoveringSearch implements DocumentSearch {
  final DocumentSearch delegate;
  bool failing = true;

  _RecoveringSearch(this.delegate);

  @override
  Future<List<DocumentSearchResult>> find(
    SearchQuery query,
    Iterable<Document> documents,
  ) {
    if (failing) throw StateError('private search failure');
    return delegate.find(query, documents);
  }
}

final class _WorkspaceFiles implements WorkspaceFiles {
  var openRequests = 0;

  @override
  Future<WorkspaceFileRef?> pickOpen() async {
    openRequests++;
    return null;
  }

  @override
  Future<WorkspaceFileRef?> pickSave({required String suggestedName}) async =>
      throw UnsupportedError('Saving is outside this shortcut test.');

  @override
  Future<String> read(WorkspaceFileRef file) =>
      throw UnsupportedError('No workspace is selected in this test.');

  @override
  Future<void> write(WorkspaceFileRef file, String contents) =>
      throw UnsupportedError('Saving is outside this shortcut test.');
}

final class _WorkspaceAccess implements WorkspaceSourceAccess {
  Never _unused() =>
      throw UnsupportedError('No workspace is selected in this test.');

  @override
  Future<void> bindFolder(
    WorkspaceId workspaceId,
    WorkspaceSourceId sourceId,
    FolderRef ref,
  ) async => _unused();

  @override
  Future<void> bindMarkdown(
    WorkspaceId workspaceId,
    WorkspaceSourceId sourceId,
    MarkdownRef ref,
  ) async => _unused();

  @override
  Future<void> forkBindings(
    WorkspaceId from,
    WorkspaceId to,
    Iterable<WorkspaceSourceId> sources,
  ) async => _unused();

  @override
  Future<WorkspaceSourceLocation> locateFolder(FolderRef ref) async =>
      _unused();

  @override
  Future<WorkspaceSourceLocation> locateMarkdown(MarkdownRef ref) async =>
      _unused();

  @override
  Future<FolderRef?> reconnectFolder(
    Workspace workspace,
    WorkspaceSource source,
  ) async => _unused();

  @override
  Future<MarkdownRef?> reconnectMarkdown(
    Workspace workspace,
    WorkspaceSource source,
  ) async => _unused();

  @override
  Future<FolderRef> restoreFolder(
    Workspace workspace,
    WorkspaceSource source,
  ) async => _unused();

  @override
  Future<MarkdownRef> restoreMarkdown(
    Workspace workspace,
    WorkspaceSource source,
  ) async => _unused();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    for (final entry in {
      'Alegreya': 'assets/fonts/Alegreya.ttf',
      'Literata': 'assets/fonts/Literata.ttf',
      'Inter': 'assets/fonts/Inter.ttf',
      'Geist Mono': 'assets/fonts/GeistMono.ttf',
    }.entries) {
      await (FontLoader(
        entry.key,
      )..addFont(rootBundle.load(entry.value))).load();
    }
  });

  late ReaderController controller;
  late List<(String, String)> saved;

  Future<void> pumpReader(
    WidgetTester tester, {
    Size size = const Size(1280, 800),
    PanelWidths? panelWidths,
    OpenWorkspace? openWorkspace,
    Future<void> Function()? openReaderSources,
    void Function(String url)? openExternal,
    bool withLibrary = true,
    Stream<ReaderUiCommand>? uiCommands,
    DocumentSearch? documentSearch,
    double topBarLeadingInset = 8,
    bool shelfVisible = true,
    bool outlineVisible = true,
    bool showWorkspaceMenu = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    saved = [];
    final repository = InMemoryLibraryRepository();
    final mutations = LibraryMutationQueue();
    const parser = MarkdownDocumentParser();
    controller = ReaderController(
      addFolder: AddFolder(
        scanner: _Scanner(),
        repository: repository,
        mutations: mutations,
      ),
      addMarkdown: AddMarkdown(
        scanner: _MarkdownScanner(),
        repository: repository,
        mutations: mutations,
      ),
      removeFolder: RemoveFolder(repository: repository, mutations: mutations),
      removeMarkdown: RemoveMarkdown(
        repository: repository,
        mutations: mutations,
      ),
      moveFolder: MoveFolder(repository: repository, mutations: mutations),
      readDocument: ReadDocument(repository: repository, parser: parser),
      searchDocuments: SearchDocuments(
        repository: repository,
        search: documentSearch ?? LiteralDocumentSearch(parser: parser),
      ),
      pickFolder: () async => null,
      openWorkspace: openWorkspace,
      sampleFolder: const FolderRef(id: 'sample', name: 'notes'),
      themes: ThemeRegistry(),
      panelWidths: panelWidths,
      shelfVisible: shelfVisible,
      outlineVisible: outlineVisible,
      savePreference: (key, value) async => saved.add((key, value)),
    );
    if (withLibrary) await controller.openSampleLibrary();

    await tester.pumpWidget(
      MaterialApp(
        theme: libraryTheme(BuiltInThemes.paper),
        home: ReaderScreen(
          controller: controller,
          openExternal: openExternal ?? (_) {},
          openReaderSources: openReaderSources,
          uiCommands: uiCommands,
          topBar: (height: 52, leadingInset: topBarLeadingInset),
          showWorkspaceMenu: showWorkspaceMenu,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Windows workspace commands live in the Visual MD wordmark', (
    tester,
  ) async {
    await pumpReader(tester, showWorkspaceMenu: true);

    expect(find.byKey(const ValueKey('workspace-menu')), findsOneWidget);
    expect(find.text('New Workspace'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('workspace-menu')));
    await tester.pumpAndSettle();

    expect(find.text('New Workspace'), findsOneWidget);
    expect(find.text('Open Workspace…'), findsOneWidget);
    expect(find.text('Add Folder…'), findsOneWidget);
    expect(find.text('Add Markdown…'), findsOneWidget);
    expect(find.text('Save Workspace'), findsOneWidget);
    expect(find.text('Save Workspace As…'), findsOneWidget);
    expect(find.text('Ctrl+Shift+O'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('New Workspace')).dx,
      greaterThanOrEqualTo(0),
      reason: 'the left-side menu must open into the window, not off-screen',
    );
  });

  testWidgets('native UI commands reuse the reader surfaces', (tester) async {
    final commands = StreamController<ReaderUiCommand>.broadcast();
    addTearDown(commands.close);
    await pumpReader(tester, uiCommands: commands.stream);

    commands.add(ReaderUiCommand.openAppearance);
    await tester.pumpAndSettle();
    expect(find.text('Follow system'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    commands.add(ReaderUiCommand.findDocument);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('document-search-field')), findsOneWidget);

    commands.add(ReaderUiCommand.showKeyboardShortcuts);
    await tester.pumpAndSettle();
    expect(find.text('Keyboard Shortcuts'), findsOneWidget);
    expect(find.text('Search Library'), findsOneWidget);
  });

  /// The width the panel wrapping [panel] currently occupies.
  double panelWidth(WidgetTester tester, Type panel) {
    final collapsible = find.ancestor(
      of: find.byType(panel),
      matching: find.byType(CollapsiblePanel),
    );
    return tester.getSize(collapsible.first).width;
  }

  Finder barButton(WidgetTester tester, String tooltipStartsWith) =>
      find.byWidgetPredicate(
        (w) =>
            w is Pressable &&
            (w.tooltip?.startsWith(tooltipStartsWith) ?? false),
      );

  Future<void> pressFind(WidgetTester tester, {bool library = false}) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    if (library) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    if (library) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'ordinary reader state does not rebuild the application theme root',
    (tester) async {
      await pumpReader(tester, withLibrary: false);
      var rootBuilds = 0;

      await tester.pumpWidget(
        VisualMdApp(
          controller: controller,
          codeHighlighter: const PlainCodeHighlighter(),
          mermaidRenderer: const UnavailableMermaidRenderer(),
          imageLoader: const SampleDocumentImageLoader(),
          viewportGeometry: const QuietDocumentViewportGeometryFactory(),
          openExternal: (_) {},
          dropRegion: (child) {
            rootBuilds++;
            return child;
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(rootBuilds, 1);

      controller.setDragging(true);
      await tester.pump();
      expect(rootBuilds, 1);

      await controller.chooseTheme(const FixedTheme('paper'));
      await tester.pump();
      expect(rootBuilds, 2);
    },
  );

  testWidgets('a fixed dark theme paints the whole Windows reader surface', (
    tester,
  ) async {
    await pumpReader(tester);
    final nativeChrome = <(int, int)>[];

    await tester.pumpWidget(
      VisualMdApp(
        controller: controller,
        codeHighlighter: const PlainCodeHighlighter(),
        mermaidRenderer: const UnavailableMermaidRenderer(),
        imageLoader: const SampleDocumentImageLoader(),
        viewportGeometry: const QuietDocumentViewportGeometryFactory(),
        openExternal: (_) {},
        showWorkspaceMenu: true,
        syncWindowChrome: (background, foreground) async {
          nativeChrome.add((background, foreground));
        },
      ),
    );
    await controller.chooseTheme(const FixedTheme('raycast-dark'));
    await tester.pumpAndSettle();

    final expected = controller.themes.byId('raycast-dark')!.palette.paper;
    final scaffold = find.byType(Scaffold).first;
    expect(
      Theme.of(tester.element(scaffold)).scaffoldBackgroundColor,
      expected,
    );
    expect(
      tester.widget<Scaffold>(scaffold).backgroundColor,
      anyOf(isNull, expected),
      reason:
          'the scaffold inherits the authored paper instead of Windows white',
    );
    expect(nativeChrome.last, (
      tester.element(scaffold).chrome.topBar.toARGB32(),
      tester.element(scaffold).palette.ink.toARGB32(),
    ));
  });

  testWidgets(
    'Open and Open Workspace keep their distinct keyboard contracts',
    (tester) async {
      final files = _WorkspaceFiles();
      final state = InMemoryReaderState();
      final sessions = InMemoryWorkspaceSessionRepository(state);
      final mutations = LibraryMutationQueue();
      const codec = WorkspaceJsonCodec();
      final autosave = WorkspaceAutosave(
        sessions: sessions,
        files: files,
        codec: codec,
        mutations: mutations,
      );
      final openWorkspace = OpenWorkspace(
        files: files,
        codec: codec,
        access: _WorkspaceAccess(),
        folders: _Scanner(),
        markdowns: _MarkdownScanner(),
        restoration: InMemoryWorkspaceRestoration(state),
        mutations: mutations,
        autosave: autosave,
      );
      var sourceOpenRequests = 0;
      await pumpReader(
        tester,
        openWorkspace: openWorkspace,
        openReaderSources: () async {
          sourceOpenRequests++;
        },
      );

      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyO);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();
      expect(sourceOpenRequests, 1, reason: 'Command-O opens reader sources');
      expect(files.openRequests, 0, reason: 'Command-O is not workspace Open');

      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyO);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pumpAndSettle();

      expect(
        files.openRequests,
        1,
        reason: 'Command-Shift-O opens a workspace',
      );
      expect(
        sourceOpenRequests,
        1,
        reason: 'Command-Shift-O is not reader-source Open',
      );
    },
  );

  testWidgets('Command-Option-O opens the sample library', (tester) async {
    await pumpReader(tester, withLibrary: false);
    expect(controller.library, isNull);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyO);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();

    expect(controller.library, isNotNull);
    expect(controller.library!.roots.single.name, 'notes');
  });

  testWidgets('the desktop launch width preserves both default side panels', (
    tester,
  ) async {
    await pumpReader(tester, size: const Size(1280, 800));

    expect(find.byType(ShelfPanel), findsOneWidget);
    expect(find.byType(OutlinePanel), findsOneWidget);
    expect(
      panelWidth(tester, ShelfPanel),
      closeTo(PanelWidths.defaultShelf, 0.001),
    );
    expect(
      panelWidth(tester, OutlinePanel),
      closeTo(PanelWidths.defaultOutline, 0.001),
    );
  });

  testWidgets(
    'scrolling into a heading rebuilds the outline without rebuilding the page',
    (tester) async {
      await pumpReader(tester, size: const Size(1280, 800));
      final before = tester.widget<ReadingPane>(find.byType(ReadingPane));

      before.onActiveHeadingChanged(
        const Heading(level: 2, text: 'Second', anchor: 'second'),
      );
      await tester.pump();

      final after = tester.widget<ReadingPane>(find.byType(ReadingPane));
      final outline = tester.widget<OutlinePanel>(find.byType(OutlinePanel));
      expect(after, same(before));
      expect(outline.activeAnchor, 'second');
    },
  );

  testWidgets('the title bar keeps document context and named commands', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpReader(tester, size: const Size(1280, 800));

    final shelf = tester.getSemantics(find.bySemanticsLabel('Hide shelf'));
    final findCommand = tester.getSemantics(
      find.bySemanticsLabel('Find in document'),
    );
    final outline = tester.getSemantics(find.bySemanticsLabel('Hide outline'));
    expect(shelf.flagsCollection.isButton, isTrue);
    expect(findCommand.flagsCollection.isButton, isTrue);
    expect(outline.flagsCollection.isButton, isTrue);
    expect(shelf.label, 'Hide shelf');
    expect(findCommand.label, 'Find in document');
    expect(outline.label, 'Hide outline');
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('top-bar-document-title')))
          .data,
      'Notes',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('top-bar-document-location')))
          .data,
      'README.md',
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(controller.shelfVisible, isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(controller.outlineVisible, isFalse);
    semantics.dispose();
  });

  testWidgets('unequal title-bar clusters cannot move the document title', (
    tester,
  ) async {
    await pumpReader(tester, topBarLeadingInset: 88);

    final barCenter = tester.getCenter(
      find.byKey(const ValueKey('reader-top-bar')),
    );
    final titleCenter = tester.getCenter(
      find.byKey(const ValueKey('top-bar-document-title')),
    );

    expect(titleCenter.dx, closeTo(barCenter.dx, 0.01));
  });

  testWidgets('the title-bar search opens the existing document finder', (
    tester,
  ) async {
    await pumpReader(tester);

    await tester.tap(barButton(tester, 'Find in document'));
    await tester.pumpAndSettle();

    expect(find.byType(DocumentFindBar), findsOneWidget);
    expect(find.byKey(const ValueKey('document-search-field')), findsOneWidget);
  });

  testWidgets('the shelf toggles on release inside', (tester) async {
    await pumpReader(tester);
    expect(panelWidth(tester, ShelfPanel), greaterThan(200));

    final press = await tester.startGesture(
      tester.getCenter(barButton(tester, 'Hide shelf')),
    );
    await tester.pump(); // still holding
    expect(controller.shelfVisible, isTrue);

    await press.up();
    await tester.pumpAndSettle();
    expect(find.byType(ShelfPanel), findsNothing);
    expect(saved, [(shelfVisiblePreference, 'false')]);

    await tester.tap(barButton(tester, 'Show shelf'));
    await tester.pumpAndSettle();
    expect(find.byType(ShelfPanel), findsOneWidget);
    expect(saved, [
      (shelfVisiblePreference, 'false'),
      (shelfVisiblePreference, 'true'),
    ]);
  });

  testWidgets('the shelf slides out rather than vanishing', (tester) async {
    await pumpReader(tester);
    final open = panelWidth(tester, ShelfPanel);

    await tester.tap(barButton(tester, 'Hide shelf'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));

    final midway = panelWidth(tester, ShelfPanel);
    expect(midway, lessThan(open));
    expect(midway, greaterThan(0));

    await tester.pumpAndSettle();
    expect(find.byType(ShelfPanel), findsNothing);
  });

  testWidgets('a failed drop remains visible over an open library', (
    tester,
  ) async {
    await pumpReader(tester);
    final openDocument = controller.reading?.document.id;

    await controller.addMarkdown(
      const MarkdownRef(id: 'missing', name: 'missing.md'),
    );
    await tester.pump();

    expect(find.byType(ErrorNotice), findsOneWidget);
    expect(find.text('Couldn\'t open “missing.md”.'), findsOneWidget);
    expect(find.byType(ShelfPanel), findsOneWidget);
    expect(controller.reading?.document.id, openDocument);

    expect(find.byTooltip('Dismiss'), findsOneWidget);
    final dismiss = find.ancestor(
      of: find.byIcon(Icons.close),
      matching: find.byType(IconButton),
    );
    tester.widget<IconButton>(dismiss).onPressed!();
    await tester.pump();

    expect(find.byType(ErrorNotice), findsNothing);
    expect(controller.error, isNull);
  });

  testWidgets(
    'the panel keeps its own width while it leaves, so it never squashes',
    (tester) async {
      await pumpReader(tester);
      final shelfWidth = tester.getSize(find.byType(ShelfPanel)).width;

      await tester.tap(barButton(tester, 'Hide shelf'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));

      expect(
        tester.getSize(find.byType(ShelfPanel)).width,
        shelfWidth,
        reason: 'contents must not reflow mid-flight',
      );
    },
  );

  testWidgets('command-f finds and counts text in the open document', (
    tester,
  ) async {
    await pumpReader(tester);

    await pressFind(tester);
    expect(find.byType(DocumentFindBar), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('document-search-field')),
      'text',
    );
    await tester.pump(const Duration(milliseconds: 130));
    await tester.pumpAndSettle();

    expect(find.text('1 of 1'), findsOneWidget);
  });

  testWidgets('a failed library search settles with recoverable copy', (
    tester,
  ) async {
    final search = _RecoveringSearch(
      LiteralDocumentSearch(parser: const MarkdownDocumentParser()),
    );
    await pumpReader(tester, documentSearch: search);
    await pressFind(tester, library: true);

    await tester.enterText(
      find.byKey(const ValueKey('library-search-field')),
      'Other',
    );
    await tester.pump(const Duration(milliseconds: 130));
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      find.text('Couldn\'t search the library. Try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('private search failure'), findsNothing);

    search.failing = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('1 match in 1 document'), findsOneWidget);
    expect(find.byType(ErrorNotice), findsNothing);
  });

  testWidgets('closing search returns keyboard focus to the reader', (
    tester,
  ) async {
    await pumpReader(tester);
    final reader = tester.widget<Focus>(
      find.byKey(const ValueKey('reader-command-focus')),
    );
    reader.focusNode!.requestFocus();
    await tester.pump();
    expect(reader.focusNode!.hasFocus, isTrue);

    await pressFind(tester);
    final field = tester.widget<EditableText>(find.byType(EditableText));
    expect(field.focusNode.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byType(DocumentFindBar), findsNothing);
    expect(reader.focusNode!.hasFocus, isTrue);
  });

  testWidgets('a fragment reaches the numbered anchor of a duplicate heading', (
    tester,
  ) async {
    await pumpReader(tester, size: const Size(960, 560));
    await controller.openDocument(
      DocumentId(const LibraryRootId('sample'), 'links.md'),
    );
    await tester.pumpAndSettle();

    final readingScroll = find.descendant(
      of: find.byType(ReadingPane),
      matching: find.byType(CustomScrollView),
    );
    final position = tester.state<ScrollableState>(
      find.descendant(of: readingScroll, matching: find.byType(Scrollable)),
    );
    expect(position.position.pixels, 0);

    expect(controller.reading?.document.id.path, 'links.md');
    await tester.tap(
      find.textContaining('Jump to the second repeated heading'),
    );
    await tester.pumpAndSettle();

    expect(position.position.pixels, greaterThan(0));
    final repeated = find.text('Repeated heading');
    expect(repeated, findsOneWidget);
    final paneTop = tester.getTopLeft(find.byType(ReadingPane)).dy;
    expect(
      tester.getTopLeft(repeated).dy,
      inInclusiveRange(paneTop, paneTop + 30),
    );
  });

  testWidgets('command-shift-f searches the library and opens a result', (
    tester,
  ) async {
    await pumpReader(tester);

    await pressFind(tester, library: true);
    expect(find.byType(LibrarySearchPanel), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('library-search-field')),
      'Other',
    );
    await tester.pump(const Duration(milliseconds: 130));
    await tester.pumpAndSettle();

    expect(find.text('1 match in 1 document'), findsOneWidget);
    await tester.tap(find.text('other.md'));
    await tester.pumpAndSettle();

    expect(controller.reading?.document.id.path, 'other.md');
    expect(find.byType(DocumentFindBar), findsOneWidget);
    expect(find.text('1 of 1'), findsOneWidget);
  });

  testWidgets('the outline also toggles on release inside', (tester) async {
    await pumpReader(tester);
    expect(panelWidth(tester, OutlinePanel), greaterThan(200));

    final press = await tester.startGesture(
      tester.getCenter(barButton(tester, 'Hide outline')),
    );
    await tester.pump();
    expect(controller.outlineVisible, isTrue);

    await press.up();
    await tester.pumpAndSettle();
    expect(find.byType(OutlinePanel), findsNothing);
    expect(saved, [(outlineVisiblePreference, 'false')]);

    await tester.tap(barButton(tester, 'Show outline'));
    await tester.pumpAndSettle();
    expect(find.byType(OutlinePanel), findsOneWidget);
    expect(saved, [
      (outlineVisiblePreference, 'false'),
      (outlineVisiblePreference, 'true'),
    ]);
  });

  testWidgets('each wide panel follows its own resize seam and remembers it', (
    tester,
  ) async {
    await pumpReader(tester, size: const Size(1800, 900));

    final shelfHandle = find.byKey(const ValueKey('shelf-resize-handle'));
    final outlineHandle = find.byKey(const ValueKey('outline-resize-handle'));
    expect(shelfHandle, findsOneWidget);
    expect(outlineHandle, findsOneWidget);

    await tester.drag(shelfHandle, const Offset(60, 0));
    await tester.pumpAndSettle();
    expect(panelWidth(tester, ShelfPanel), closeTo(340, 1));
    expect(saved, contains((shelfWidthPreference, '340.0')));

    await tester.drag(outlineHandle, const Offset(-40, 0));
    await tester.pumpAndSettle();
    expect(panelWidth(tester, OutlinePanel), closeTo(280, 1));
    expect(saved, contains((outlineWidthPreference, '280.0')));
  });

  testWidgets('the shelf remembers whether rows use titles or file names', (
    tester,
  ) async {
    await pumpReader(tester, size: const Size(1800, 900));

    await tester.tap(find.byKey(const ValueKey('shelf-label-mode-toggle')));
    await tester.pump();

    expect(controller.shelfLabelMode, ShelfLabelMode.fileName);
    expect(
      saved,
      contains((shelfLabelModePreference, ShelfLabelMode.fileName.stored)),
    );
  });

  testWidgets('the resize seam resets on double-click and moves by keyboard', (
    tester,
  ) async {
    await pumpReader(
      tester,
      size: const Size(1800, 900),
      panelWidths: const PanelWidths(shelf: 360),
    );
    final handle = find.byKey(const ValueKey('shelf-resize-handle'));

    await tester.tap(handle);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(panelWidth(tester, ShelfPanel), closeTo(376, 1));

    await tester.tap(handle);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(handle);
    await tester.pumpAndSettle();
    expect(panelWidth(tester, ShelfPanel), closeTo(280, 1));
    expect(saved, contains((shelfWidthPreference, '280.0')));
  });

  testWidgets('large preferences yield before they squeeze the reading pane', (
    tester,
  ) async {
    await pumpReader(
      tester,
      panelWidths: const PanelWidths(shelf: 520, outline: 440),
    );

    expect(tester.getSize(find.byType(ReadingPane)).width, greaterThan(650));
  });

  testWidgets('a resize seam stops rather than moving the opposite panel', (
    tester,
  ) async {
    await pumpReader(tester);
    final outlineBefore = panelWidth(tester, OutlinePanel);

    await tester.drag(
      find.byKey(const ValueKey('shelf-resize-handle')),
      const Offset(200, 0),
    );
    await tester.pumpAndSettle();

    expect(panelWidth(tester, OutlinePanel), closeTo(outlineBefore, 0.01));
    expect(tester.getSize(find.byType(ReadingPane)).width, greaterThan(650));
  });

  testWidgets('reduce motion swaps the panels at once', (tester) async {
    await pumpReader(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: libraryTheme(BuiltInThemes.paper),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: ReaderScreen(controller: controller, openExternal: (_) {}),
      ),
    );
    await tester.pumpAndSettle();

    final titleSwitcher = tester.widget<AnimatedSwitcher>(
      find
          .ancestor(
            of: find.byKey(const ValueKey('top-bar-document-title')),
            matching: find.byType(AnimatedSwitcher),
          )
          .first,
    );
    final shelfIconSwitcher = tester.widget<AnimatedSwitcher>(
      find
          .descendant(
            of: barButton(tester, 'Hide shelf'),
            matching: find.byType(AnimatedSwitcher),
          )
          .first,
    );
    final resizeHighlight = tester.widget<AnimatedContainer>(
      find
          .descendant(
            of: find.byKey(const ValueKey('shelf-resize-handle')),
            matching: find.byType(AnimatedContainer),
          )
          .first,
    );
    expect(titleSwitcher.duration, Duration.zero);
    expect(shelfIconSwitcher.duration, Duration.zero);
    expect(resizeHighlight.duration, Duration.zero);

    await tester.tap(barButton(tester, 'Hide shelf'));
    await tester.pump();
    expect(find.byType(ShelfPanel), findsNothing);
  });

  testWidgets(
    'a compact window opens on the page and uses one panel as an overlay',
    (tester) async {
      await pumpReader(tester);
      tester.view.physicalSize = const Size(720, 480);
      await tester.pumpAndSettle();

      expect(find.byType(ReadingPane), findsOneWidget);
      expect(find.byType(ShelfPanel), findsNothing);
      expect(find.byType(OutlinePanel), findsNothing);
      expect(find.byType(PanelResizeHandle), findsNothing);

      await tester.tap(barButton(tester, 'Show shelf'));
      await tester.pumpAndSettle();
      expect(find.byType(ShelfPanel), findsOneWidget);
      expect(find.byType(OutlinePanel), findsNothing);

      final shelf = tester.widget<ShelfPanel>(find.byType(ShelfPanel));
      shelf.onSelect(DocumentId(const LibraryRootId('sample'), 'other.md'));
      await tester.pumpAndSettle();
      expect(find.byType(ShelfPanel), findsNothing);
      expect(controller.reading!.document.fileName, 'other.md');

      await tester.tap(barButton(tester, 'Show shelf'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('compact-panel-dismiss-region')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ShelfPanel), findsNothing);

      await tester.tap(barButton(tester, 'Show outline'));
      await tester.pumpAndSettle();
      expect(find.byType(ShelfPanel), findsNothing);
      expect(find.byType(OutlinePanel), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(OutlinePanel), findsNothing);

      await tester.tap(barButton(tester, 'Show shelf'));
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.period);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pumpAndSettle();
      expect(find.byType(ShelfPanel), findsNothing);
      expect(controller.shelfVisible, isTrue);
      expect(controller.outlineVisible, isTrue);
      expect(saved, isEmpty);
    },
  );

  testWidgets('restored panel choices set the initial wide layout', (
    tester,
  ) async {
    await pumpReader(tester, shelfVisible: false, outlineVisible: false);

    expect(find.byType(ShelfPanel), findsNothing);
    expect(find.byType(OutlinePanel), findsNothing);
    expect(barButton(tester, 'Show shelf'), findsOneWidget);
    expect(barButton(tester, 'Show outline'), findsOneWidget);
    expect(saved, isEmpty);
  });

  testWidgets('Command-Period cancels search instead of toggling the outline', (
    tester,
  ) async {
    await pumpReader(tester);
    expect(find.byType(OutlinePanel), findsOneWidget);

    await pressFind(tester);
    expect(find.byKey(const ValueKey('document-search-field')), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.period);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('document-search-field')), findsNothing);
    expect(find.byType(OutlinePanel), findsOneWidget);
  });
}
