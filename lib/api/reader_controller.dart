// ignore_for_file: prefer_initializing_formals — private fields stay private; named params stay public.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart'
    show ChangeNotifier, ValueListenable, ValueNotifier;
import 'package:flutter/material.dart' show Brightness;

import '../application/ports/folder_scanner.dart';
import '../application/ports/markdown_scanner.dart';
import '../application/ports/workspace_session_repository.dart';
import '../application/source_watch_coordinator.dart';
import '../application/use_cases/add_folder.dart';
import '../application/use_cases/add_markdown.dart';
import '../application/use_cases/enrich_folder_titles.dart';
import '../application/use_cases/move_folder.dart';
import '../application/use_cases/create_workspace.dart';
import '../application/use_cases/open_workspace.dart';
import '../application/use_cases/read_document.dart';
import '../application/use_cases/refresh_source.dart';
import '../application/use_cases/reconnect_workspace_source.dart';
import '../application/use_cases/remove_folder.dart';
import '../application/use_cases/remove_markdown.dart';
import '../application/use_cases/search_documents.dart';
import '../application/use_cases/save_workspace.dart';
import '../application/use_cases/update_workspace.dart';
import '../domain/library/document_id.dart';
import '../domain/library/library.dart';
import '../domain/library/library_root_id.dart';
import '../domain/search/search_result.dart';
import '../domain/workspace/workspace_theme.dart';
import '../domain/workspace/workspace_id.dart';
import '../presentation/theme/reader_theme.dart';
import '../presentation/theme/reading_scale.dart';
import '../presentation/shelf/shelf_label_mode.dart';
import '../presentation/theme/theme_choice.dart';
import '../presentation/theme/theme_registry.dart';
import 'layout/panel_widths.dart';

/// Where a link in a document leads.
sealed class LinkTarget {}

final class AnchorLink extends LinkTarget {
  final String anchor;
  AnchorLink(this.anchor);
}

final class DocumentLink extends LinkTarget {
  final DocumentId id;
  final String? anchor;
  DocumentLink(this.id, this.anchor);
}

final class ExternalLink extends LinkTarget {
  final String url;
  ExternalLink(this.url);
}

/// The small part of reader state that changes Flutter's application theme.
///
/// Keeping this projection separate prevents library, search, and document
/// updates from rebuilding the application root above the reader shell.
final class ReaderAppearance {
  final ThemeChoice themeChoice;
  final String? serifOverride;

  const ReaderAppearance({
    required this.themeChoice,
    required this.serifOverride,
  });

  ReaderAppearance copyWith({
    ThemeChoice? themeChoice,
    String? serifOverride,
    bool clearSerifOverride = false,
  }) => ReaderAppearance(
    themeChoice: themeChoice ?? this.themeChoice,
    serifOverride: clearSerifOverride
        ? null
        : serifOverride ?? this.serifOverride,
  );
}

/// UI state for the reader. Talks to use cases only; the UI talks to it.
final class ReaderController extends ChangeNotifier {
  final AddFolder _addFolder;
  final AddMarkdown _addMarkdown;
  final EnrichFolderTitles? _enrichFolderTitles;
  final RemoveFolder _removeFolder;
  final RemoveMarkdown _removeMarkdown;
  final MoveFolder _moveFolder;
  final ReadDocument _readDocument;
  final SearchDocuments _searchDocuments;
  final Future<FolderRef?> Function() _pickFolder;
  final Future<MarkdownRef?> Function()? _pickMarkdown;
  final CreateWorkspace? _createWorkspace;
  final OpenWorkspace? _openWorkspace;
  final SaveWorkspace? _saveWorkspace;
  final SaveWorkspaceAs? _saveWorkspaceAs;
  final UpdateWorkspace? _updateWorkspace;
  final ReconnectWorkspaceSource? _reconnectWorkspaceSource;
  final Future<WorkspaceSession?> Function()? _currentWorkspace;
  final FolderRef _sampleFolder;
  final Future<void> Function(String key, String value) _savePreference;
  final SourceWatchCoordinator? _sourceChanges;
  StreamSubscription<SourceSyncEvent>? _sourceChangeSubscription;

  ReaderController({
    required AddFolder addFolder,
    required AddMarkdown addMarkdown,
    EnrichFolderTitles? enrichFolderTitles,
    required RemoveFolder removeFolder,
    required RemoveMarkdown removeMarkdown,
    required MoveFolder moveFolder,
    required ReadDocument readDocument,
    required SearchDocuments searchDocuments,
    required Future<FolderRef?> Function() pickFolder,
    Future<MarkdownRef?> Function()? pickMarkdown,
    CreateWorkspace? createWorkspace,
    OpenWorkspace? openWorkspace,
    SaveWorkspace? saveWorkspace,
    SaveWorkspaceAs? saveWorkspaceAs,
    UpdateWorkspace? updateWorkspace,
    ReconnectWorkspaceSource? reconnectWorkspaceSource,
    Future<WorkspaceSession?> Function()? currentWorkspace,
    WorkspaceSession? workspaceSession,
    required FolderRef sampleFolder,
    required this.themes,
    ThemeChoice? themeChoice,
    ReadingScale? readingScale,
    PanelWidths? panelWidths,
    ShelfLabelMode? shelfLabelMode,
    SourceWatchCoordinator? sourceChanges,
    Future<void> Function(String key, String value)? savePreference,
  }) : _addFolder = addFolder,
       _addMarkdown = addMarkdown,
       _enrichFolderTitles = enrichFolderTitles,
       _removeFolder = removeFolder,
       _removeMarkdown = removeMarkdown,
       _moveFolder = moveFolder,
       _readDocument = readDocument,
       _searchDocuments = searchDocuments,
       _pickFolder = pickFolder,
       _pickMarkdown = pickMarkdown,
       _createWorkspace = createWorkspace,
       _openWorkspace = openWorkspace,
       _saveWorkspace = saveWorkspace,
       _saveWorkspaceAs = saveWorkspaceAs,
       _updateWorkspace = updateWorkspace,
       _reconnectWorkspaceSource = reconnectWorkspaceSource,
       _currentWorkspace = currentWorkspace,
       _sampleFolder = sampleFolder,
       _sourceChanges = sourceChanges,
       _savePreference = savePreference ?? _discard,
       readingScale = readingScale ?? ReadingScale.comfortable,
       panelWidths = panelWidths ?? const PanelWidths(),
       shelfLabelMode = shelfLabelMode ?? ShelfLabelMode.title,
       workspaceSession = workspaceSession {
    _appearance = ValueNotifier(
      ReaderAppearance(
        themeChoice: themeChoice ?? themes.systemPair,
        serifOverride: null,
      ),
    );
    _sourceChangeSubscription = sourceChanges?.events.listen(
      _handleSourceSyncEvent,
    );
  }

  static Future<void> _discard(String key, String value) async {}

  Library? library;
  DocumentReading? reading;
  bool opening = false;
  var _sourcesOpening = 0;
  var _nextFolderTitleRevision = 0;
  final Map<LibraryRootId, int> _folderTitleRevisions = {};
  var _disposed = false;
  var _expandRevision = 0;
  ({DocumentId id, int revision})? expandRequest;
  bool dragging = false;
  String? error;
  String? _sourceSyncError;
  int contentRevision = 0;
  bool shelfVisible = true;
  bool outlineVisible = true;
  WorkspaceSession? workspaceSession;

  String? get workspaceName => workspaceSession?.file?.name;

  bool get hasUnavailableSources =>
      workspaceSession?.unavailableSources.isNotEmpty ?? false;

  Set<WorkspaceSourceId> get unavailableSources =>
      workspaceSession?.unavailableSources ?? const {};

  /// Every theme the reader can wear, and what it currently wears.
  final ThemeRegistry themes;
  late final ValueNotifier<ReaderAppearance> _appearance;

  ValueListenable<ReaderAppearance> get appearance => _appearance;

  ThemeChoice get themeChoice => _appearance.value.themeChoice;

  set themeChoice(ThemeChoice value) {
    if (value == themeChoice) return;
    _appearance.value = _appearance.value.copyWith(themeChoice: value);
  }

  /// The proportions of the reading column — body size, and everything cut
  /// from it.
  ReadingScale readingScale;

  /// The reader's preferred shelf and outline widths. The shell may fit these
  /// to a smaller window without changing the remembered values.
  PanelWidths panelWidths;

  /// Whether shelf rows identify documents by authored title or file name.
  ShelfLabelMode shelfLabelMode;

  /// A reading face named at launch, overriding whatever the theme asks for.
  /// Not persisted: it is for judging a face, not for living with one.
  String? get serifOverride => _appearance.value.serifOverride;

  set serifOverride(String? value) {
    if (value == serifOverride) return;
    _appearance.value = _appearance.value.copyWith(
      serifOverride: value,
      clearSerifOverride: value == null,
    );
  }

  Future<void> addFolder(FolderRef ref, {int? atIndex}) async {
    final rootId = LibraryRootId(ref.id);
    final titleRevision = ++_nextFolderTitleRevision;
    _folderTitleRevisions[rootId] = titleRevision;
    _sourcesOpening++;
    opening = true;
    error = null;
    notifyListeners();
    try {
      final selected = reading?.document.id;
      final added = await _addFolder.execute(
        ref,
        selected: selected,
        atIndex: atIndex,
      );
      library = added.library;
      _sourceChanges?.watchFolder(ref);
      _sourceChanges?.retainLibrary(library);
      notifyListeners();
      final deferredTitles = added.deferredTitles;
      if (deferredTitles != null) {
        _scheduleTitleEnrichment(rootId, titleRevision, deferredTitles);
      }
      final next = added.nextDocument;
      if (added.refreshed) {
        _readDocument.invalidate(added.root.documents.map((item) => item.id));
        _searchDocuments.invalidate(
          added.root.documents.map((item) => item.id),
        );
      }
      _readDocument.retain(added.library.documents.map((item) => item.id));
      _searchDocuments.retain(added.library.documents.map((item) => item.id));
      if (next != null &&
          (next.id != selected ||
              (added.refreshed && selected?.rootId == added.root.id))) {
        reading = await _readDocument.execute(next.id);
      }
      if (added.adaptedDocument != null) {
        _requestExpand(added.adaptedDocument!.id);
      }
      await _refreshWorkspaceSession();
      error = null;
    } on Object {
      error = "Couldn't open “${ref.name}”.";
    } finally {
      _sourcesOpening--;
      opening = _sourcesOpening > 0;
      notifyListeners();
    }
  }

  Future<void> addMarkdown(MarkdownRef ref, {int? atIndex}) async {
    _sourcesOpening++;
    opening = true;
    error = null;
    notifyListeners();
    try {
      final added = await _addMarkdown.execute(ref, atIndex: atIndex);
      library = added.library;
      if (added.containingRoot == null) {
        _sourceChanges?.watchMarkdown(ref);
      }
      _sourceChanges?.retainLibrary(library);
      _readDocument.invalidate([added.document.id]);
      _readDocument.retain(added.library.documents.map((item) => item.id));
      _searchDocuments.invalidate([added.document.id]);
      _searchDocuments.retain(added.library.documents.map((item) => item.id));
      reading = await _readDocument.execute(added.document.id);
      final containingRoot = added.containingRoot;
      if (containingRoot != null) {
        _requestExpand(added.document.id);
      }
      await _refreshWorkspaceSession();
      error = null;
    } on Object {
      error = "Couldn't open “${ref.name}”.";
    } finally {
      _sourcesOpening--;
      opening = _sourcesOpening > 0;
      notifyListeners();
    }
  }

  void _requestExpand(DocumentId id) {
    expandRequest = (id: id, revision: ++_expandRevision);
  }

  Future<void> pickAndAddFolder() async {
    try {
      final ref = await _pickFolder();
      if (ref != null) await addFolder(ref);
    } on Object catch (failure) {
      error = "Couldn't choose a folder: $failure";
      notifyListeners();
    }
  }

  Future<void> pickAndAddMarkdown() async {
    try {
      final ref = await _pickMarkdown?.call();
      if (ref != null) await addMarkdown(ref);
    } on Object catch (failure) {
      error = "Couldn't choose a markdown file: $failure";
      notifyListeners();
    }
  }

  Future<void> openSampleLibrary() async {
    await addFolder(_sampleFolder);
    final sample = library?.rootById(LibraryRootId(_sampleFolder.id));
    final opening = sample?.openingDocument;
    if (opening != null) await openDocument(opening.id);
  }

  Future<void> newWorkspace() async {
    final create = _createWorkspace;
    if (create == null || opening) return;
    opening = true;
    error = null;
    notifyListeners();
    try {
      workspaceSession = await create.execute(_workspaceTheme(themeChoice));
      library = null;
      reading = null;
      _readDocument.clear();
      _searchDocuments.clear();
      _sourceChanges?.replace(folders: const [], markdowns: const []);
      _folderTitleRevisions.clear();
      error = null;
    } on Object {
      error = "Couldn't create a new workspace.";
    } finally {
      opening = false;
      notifyListeners();
    }
  }

  Future<void> openWorkspace() async {
    final open = _openWorkspace;
    if (open == null || opening) return;
    opening = true;
    error = null;
    notifyListeners();
    try {
      final result = await open.execute();
      if (result == null) return;
      workspaceSession = result.session;
      library = result.session.workspace.isEmpty ? null : result.library;
      _readDocument.clear();
      _searchDocuments.clear();
      _sourceChanges?.replace(
        folders: result.folderRefs,
        markdowns: result.markdownRefs,
      );
      _folderTitleRevisions.clear();
      for (final deferred in result.deferredTitles) {
        final rootId = LibraryRootId(deferred.ref.id);
        final revision = ++_nextFolderTitleRevision;
        _folderTitleRevisions[rootId] = revision;
        _scheduleTitleEnrichment(rootId, revision, deferred);
      }
      notifyListeners();
      final document = result.activeDocument;
      reading = document == null
          ? null
          : await _readDocument.execute(document.id);
      themeChoice = _themeChoice(result.session.workspace.theme);
      if (document != null) _requestExpand(document.id);
      final unavailable = result.session.unavailableSources.length;
      error = unavailable == 0
          ? null
          : '$unavailable ${unavailable == 1 ? 'source needs' : 'sources need'} to be reconnected.';
    } on Object catch (failure) {
      error = "Couldn't open workspace: $failure";
    } finally {
      opening = false;
      notifyListeners();
    }
  }

  Future<void> saveWorkspace() async {
    final save = _saveWorkspace;
    if (save == null) return;
    try {
      workspaceSession = await save.execute() ?? workspaceSession;
      error = null;
    } on Object catch (failure) {
      error = "Couldn't save workspace: $failure";
    }
    notifyListeners();
  }

  Future<void> saveWorkspaceAs() async {
    final save = _saveWorkspaceAs;
    if (save == null) return;
    try {
      workspaceSession = await save.execute() ?? workspaceSession;
      error = null;
    } on Object catch (failure) {
      error = "Couldn't save workspace: $failure";
    }
    notifyListeners();
  }

  Future<void> reconnectSource(WorkspaceSourceId id) async {
    final reconnect = _reconnectWorkspaceSource;
    if (reconnect == null) return;
    try {
      switch (await reconnect.execute(id)) {
        case ReconnectedFolder(:final ref, :final insertionIndex):
          await addFolder(ref, atIndex: insertionIndex);
        case ReconnectedMarkdown(:final ref, :final insertionIndex):
          await addMarkdown(ref, atIndex: insertionIndex);
        case null:
          return;
      }
      error = null;
    } on Object catch (failure) {
      error = "Couldn't reconnect source: $failure";
      notifyListeners();
    }
  }

  Future<void> removeUnavailableSource(WorkspaceSourceId id) async {
    try {
      workspaceSession =
          await _updateWorkspace?.removeUnavailable(id) ?? workspaceSession;
      if (workspaceSession?.unavailableSources.isEmpty ?? true) error = null;
    } on Object catch (failure) {
      error = "Couldn't remove source: $failure";
    }
    notifyListeners();
  }

  Future<void> removeFolder(LibraryRootId id) async {
    _folderTitleRevisions[id] = ++_nextFolderTitleRevision;
    try {
      final removed = await _removeFolder.execute(
        id,
        selected: reading?.document.id,
      );
      library = removed.library.isEmpty ? null : removed.library;
      _readDocument.retain(removed.library.documents.map((item) => item.id));
      _searchDocuments.retain(removed.library.documents.map((item) => item.id));
      _sourceChanges?.retainLibrary(library);
      if (reading?.document.id.rootId == id) {
        final next = removed.nextDocument;
        reading = next == null ? null : await _readDocument.execute(next.id);
      }
      await _refreshWorkspaceSession();
      error = null;
    } on Object catch (failure) {
      error = "Couldn't remove folder: $failure";
    }
    notifyListeners();
  }

  Future<void> removeMarkdown(DocumentId id) async {
    try {
      final removed = await _removeMarkdown.execute(
        id,
        selected: reading?.document.id,
      );
      library = removed.library.isEmpty ? null : removed.library;
      _readDocument.retain(removed.library.documents.map((item) => item.id));
      _searchDocuments.retain(removed.library.documents.map((item) => item.id));
      _sourceChanges?.retainLibrary(library);
      if (reading?.document.id == id) {
        final next = removed.nextDocument;
        reading = next == null ? null : await _readDocument.execute(next.id);
      }
      await _refreshWorkspaceSession();
      error = null;
    } on Object catch (failure) {
      error = "Couldn't remove markdown: $failure";
    }
    notifyListeners();
  }

  Future<void> moveFolder(LibraryRootId id, int toIndex) async {
    try {
      library = await _moveFolder.execute(
        id,
        toIndex,
        selected: reading?.document.id,
      );
      await _refreshWorkspaceSession();
      error = null;
    } on Object catch (failure) {
      error = "Couldn't arrange folders: $failure";
    }
    notifyListeners();
  }

  Future<void> openDocument(DocumentId id) async {
    if (reading?.document.id == id) return;
    final next = await _readDocument.execute(id);
    final open = library;
    if (open != null) await _updateWorkspace?.rememberActive(open, id);
    reading = next;
    await _refreshWorkspaceSession();
    notifyListeners();
  }

  Future<List<DocumentSearchResult>> search(
    String text, {
    DocumentId? within,
  }) => _searchDocuments.execute(text, within: within);

  /// Decides what a clicked link means in the context of the open document.
  LinkTarget? resolveLink(String href) {
    if (href.isEmpty) return null;
    if (href.startsWith('#')) {
      return AnchorLink(_decodedFragment(href.substring(1)));
    }
    final uri = Uri.tryParse(href);
    if (uri != null && uri.hasScheme) {
      // Markdown admits arbitrary URI schemes, but these three execute or
      // embed authored payloads instead of handing a destination to another
      // application. They must never cross the platform-opening boundary.
      const executable = {'javascript', 'data', 'vbscript'};
      return executable.contains(uri.scheme.toLowerCase())
          ? null
          : ExternalLink(href);
    }

    final current = reading?.document;
    final open = library;
    if (current == null || open == null) return null;

    final hash = href.indexOf('#');
    final path = hash < 0 ? href : href.substring(0, hash);
    final anchor = hash < 0 ? null : _decodedFragment(href.substring(hash + 1));
    if (path.isEmpty) return anchor == null ? null : AnchorLink(anchor);

    final candidates = [
      current.id.resolve(path),
      current.id.resolve('$path.md'),
    ];
    for (final id in candidates) {
      if (open.find(id) != null) return DocumentLink(id, anchor);
    }
    return null;
  }

  /// URI fragments arrive percent-encoded even when Markdown used the
  /// angle-bracket form to spell spaces. Custom HTML anchor names are already
  /// decoded by the HTML parser, so navigation must compare decoded identities.
  /// A malformed escape remains literal instead of making a link click throw.
  static String _decodedFragment(String fragment) {
    try {
      return Uri.decodeComponent(fragment);
    } on ArgumentError {
      return fragment;
    }
  }

  void setDragging(bool value) {
    if (dragging == value) return;
    dragging = value;
    notifyListeners();
  }

  void clearError() {
    if (error == null) return;
    error = null;
    notifyListeners();
  }

  void reportWorkspaceAutosaveFailure(Object failure) {
    error = "Couldn't autosave workspace: $failure";
    notifyListeners();
  }

  void toggleShelf() {
    shelfVisible = !shelfVisible;
    notifyListeners();
  }

  void toggleOutline() {
    outlineVisible = !outlineVisible;
    notifyListeners();
  }

  /// The theme to wear for the system's brightness.
  ReaderTheme themeFor(Brightness system) =>
      themes.resolve(themeChoice, system);

  Future<void> chooseTheme(ThemeChoice choice) async {
    if (choice == themeChoice) return;
    try {
      workspaceSession =
          await _updateWorkspace?.chooseTheme(_workspaceTheme(choice)) ??
          workspaceSession;
      themeChoice = choice;
      error = null;
      notifyListeners();
      await _savePreference(themePreference, jsonEncode(choice.toJson()));
    } on Object catch (failure) {
      error = "Couldn't save the workspace theme: $failure";
      notifyListeners();
    }
  }

  Future<void> markParagraphs(ParagraphMarking marking) async {
    if (marking == readingScale.marking) return;
    readingScale = readingScale.copyWith(marking: marking);
    notifyListeners();
    await _savePreference(paragraphsPreference, readingScale.storedMarking);
  }

  Future<void> enlargeText() => _setScale(readingScale.larger());

  Future<void> shrinkText() => _setScale(readingScale.smaller());

  Future<void> resetText() => _setScale(ReadingScale.comfortable);

  void previewShelfWidth(double width) {
    final next = panelWidths.withShelf(width);
    if (next.shelf == panelWidths.shelf) return;
    panelWidths = next;
    notifyListeners();
  }

  void previewOutlineWidth(double width) {
    final next = panelWidths.withOutline(width);
    if (next.outline == panelWidths.outline) return;
    panelWidths = next;
    notifyListeners();
  }

  Future<void> rememberShelfWidth() =>
      _savePreference(shelfWidthPreference, panelWidths.shelf.toString());

  Future<void> rememberOutlineWidth() =>
      _savePreference(outlineWidthPreference, panelWidths.outline.toString());

  Future<void> resetShelfWidth() async {
    if (panelWidths.shelf == PanelWidths.defaultShelf) return;
    panelWidths = panelWidths.resetShelf();
    notifyListeners();
    await rememberShelfWidth();
  }

  Future<void> resetOutlineWidth() async {
    if (panelWidths.outline == PanelWidths.defaultOutline) return;
    panelWidths = panelWidths.resetOutline();
    notifyListeners();
    await rememberOutlineWidth();
  }

  Future<void> chooseShelfLabelMode(ShelfLabelMode mode) async {
    if (mode == shelfLabelMode) return;
    shelfLabelMode = mode;
    notifyListeners();
    await _savePreference(shelfLabelModePreference, mode.stored);
  }

  Future<void> _setScale(ReadingScale scale) async {
    if (scale == readingScale) return;
    readingScale = scale;
    notifyListeners();
    await _savePreference(textSizePreference, scale.storedBase);
  }

  Future<void> _refreshWorkspaceSession() async {
    workspaceSession = await _currentWorkspace?.call() ?? workspaceSession;
  }

  void _handleSourceSyncEvent(SourceSyncEvent event) {
    switch (event) {
      case SourceSynchronized(:final result):
        unawaited(_applySourceRefresh(result));
      case SourceSynchronizationFailed(:final sourceName, :final reason):
        final message = "Couldn't keep “$sourceName” up to date: $reason";
        _sourceSyncError = message;
        error = message;
        notifyListeners();
    }
  }

  Future<void> _applySourceRefresh(RefreshedSource result) async {
    final selected = reading?.document.id;
    library = result.library;
    _readDocument.invalidate(result.changedDocuments);
    _readDocument.retain(result.library.documents.map((item) => item.id));
    _searchDocuments.invalidate(result.changedDocuments);
    _searchDocuments.retain(result.library.documents.map((item) => item.id));
    _sourceChanges?.retainLibrary(library);
    if (selected != null &&
        (result.changedDocuments.contains(selected) ||
            result.library.find(selected) == null)) {
      final active = result.activeDocument;
      reading = active == null ? null : await _readDocument.execute(active);
    }
    contentRevision++;
    await _refreshWorkspaceSession();
    if (error == _sourceSyncError) error = null;
    _sourceSyncError = null;
    notifyListeners();
  }

  void _scheduleTitleEnrichment(
    LibraryRootId rootId,
    int revision,
    DeferredFolderTitles deferred,
  ) {
    final enrich = _enrichFolderTitles;
    if (enrich == null) return;
    unawaited(() async {
      try {
        final result = await enrich.execute(
          deferred,
          isCurrent: () =>
              !_disposed && _folderTitleRevisions[rootId] == revision,
        );
        if (result == null ||
            _disposed ||
            _folderTitleRevisions[rootId] != revision) {
          return;
        }
        library = result.library;
        notifyListeners();
      } on Object {
        // A filename is the lossless fallback. Deferred metadata failure must
        // not turn a successfully opened folder into an error state.
      }
    }());
  }

  void reportReaderSourcePickerFailure(Object failure) {
    error = "Couldn't choose a folder or Markdown file: $failure";
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _folderTitleRevisions.clear();
    _readDocument.clear();
    _searchDocuments.clear();
    _appearance.dispose();
    unawaited(_sourceChangeSubscription?.cancel());
    unawaited(_sourceChanges?.dispose());
    super.dispose();
  }
}

WorkspaceTheme _workspaceTheme(ThemeChoice choice) => switch (choice) {
  FixedTheme(:final id) => FixedWorkspaceTheme(id),
  FollowSystem(:final light, :final dark) => SystemWorkspaceTheme(
    lightThemeId: light,
    darkThemeId: dark,
  ),
};

ThemeChoice _themeChoice(WorkspaceTheme theme) => switch (theme) {
  FixedWorkspaceTheme(:final themeId) => FixedTheme(themeId),
  SystemWorkspaceTheme(:final lightThemeId, :final darkThemeId) => FollowSystem(
    light: lightThemeId,
    dark: darkThemeId,
  ),
};

/// Keys the reader's choices are stored under.
const themePreference = 'theme';
const textSizePreference = 'textSize';
const paragraphsPreference = 'paragraphs';
const shelfWidthPreference = 'shelfWidth';
const outlineWidthPreference = 'outlineWidth';
const shelfLabelModePreference = 'shelfLabelMode';
