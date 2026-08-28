import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../application/ports/document_image_loader.dart';
import '../../application/ports/document_viewport_geometry.dart';
import '../../application/ports/shelf_source_actions.dart';
import '../../domain/reading/heading.dart';
import '../../domain/reading/table_of_contents.dart';
import '../../domain/search/search_result.dart';
import '../../presentation/code/code_highlighter.dart';
import '../../application/ports/mermaid_renderer.dart';
import '../layout/panel_widths.dart';
import '../render/reading_theme.dart';
import '../reader_controller.dart';
import '../theme/library_theme.dart';
import '../theme/library_chrome.dart';
import '../widgets/brand_mark.dart';
import '../widgets/collapsible_panel.dart';
import '../widgets/drop_overlay.dart';
import '../widgets/error_notice.dart';
import '../widgets/outline_panel.dart';
import '../widgets/panel_resize_handle.dart';
import '../widgets/pressable.dart';
import '../widgets/reading_pane.dart';
import '../widgets/search_view.dart';
import '../widgets/shelf_panel.dart';
import '../widgets/theme_picker.dart';
import '../widgets/welcome_view.dart';

enum _SearchMode { closed, document, library }

/// The room: shelf on the left, page in the middle, outline on the right.
class ReaderScreen extends StatefulWidget {
  final ReaderController controller;
  final CodeHighlighter codeHighlighter;
  final MermaidRenderer mermaidRenderer;
  final DocumentImageLoader? imageLoader;
  final DocumentViewportGeometryFactory? viewportGeometry;
  final void Function(String url) openExternal;
  final Future<void> Function()? openReaderSources;
  final ShelfSourceActions? shelfSourceActions;
  final ({double height, double leadingInset}) topBar;
  final Widget Function(Widget child) windowDragRegion;

  /// Reveals the custom-theme directory; null where custom files are absent.
  final Future<void> Function()? openThemesFolder;

  const ReaderScreen({
    super.key,
    required this.controller,
    required this.openExternal,
    this.codeHighlighter = const PlainCodeHighlighter(),
    this.mermaidRenderer = const UnavailableMermaidRenderer(),
    this.imageLoader,
    this.viewportGeometry,
    this.openReaderSources,
    this.shelfSourceActions,
    this.topBar = (height: 52, leadingInset: 8),
    this.windowDragRegion = _identity,
    this.openThemesFolder,
  });

  static Widget _identity(Widget child) => child;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  static const _compactBreakpoint = 1180.0;

  final _pane = GlobalKey<ReadingPaneState>();
  final _activeAnchor = ValueNotifier<String?>(null);
  bool _compactShelfVisible = false;
  bool _compactOutlineVisible = false;
  final _searchText = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _searchDebounce;
  _SearchMode _searchMode = _SearchMode.closed;
  List<DocumentSearchResult> _searchResults = const [];
  int _activeMatch = 0;
  int _searchRequest = 0;
  bool _searching = false;
  late int _seenContentRevision;

  ReaderController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    _seenContentRevision = c.contentRevision;
    c.addListener(_handleControllerChange);
  }

  @override
  void didUpdateWidget(ReaderScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_handleControllerChange);
    _seenContentRevision = c.contentRevision;
    c.addListener(_handleControllerChange);
  }

  void _handleControllerChange() {
    if (_seenContentRevision == c.contentRevision) return;
    _seenContentRevision = c.contentRevision;
    if (_searchMode != _SearchMode.closed && _searchText.text.isNotEmpty) {
      unawaited(_searchNow());
    }
  }

  @override
  void dispose() {
    c.removeListener(_handleControllerChange);
    _searchDebounce?.cancel();
    _activeAnchor.dispose();
    _searchText.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _openSearch(_SearchMode mode) {
    if (c.library == null ||
        (mode == _SearchMode.document && c.reading == null)) {
      return;
    }
    setState(() {
      _searchMode = mode;
      _searchResults = const [];
      _activeMatch = 0;
      _searching = _searchText.text.isNotEmpty;
    });
    _searchNow();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocus.requestFocus();
      _searchText.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _searchText.text.length,
      );
    });
  }

  void _closeSearch() {
    _searchDebounce?.cancel();
    _searchRequest++;
    setState(() {
      _searchMode = _SearchMode.closed;
      _searchResults = const [];
      _activeMatch = 0;
      _searching = false;
    });
  }

  void _searchChanged(String value) {
    _searchDebounce?.cancel();
    if (value.isEmpty) {
      _searchRequest++;
      setState(() {
        _searchResults = const [];
        _activeMatch = 0;
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _searchDebounce = Timer(const Duration(milliseconds: 120), _searchNow);
  }

  Future<void> _searchNow() async {
    final text = _searchText.text;
    final mode = _searchMode;
    if (text.isEmpty || mode == _SearchMode.closed) return;
    final request = ++_searchRequest;
    final results = await c.search(
      text,
      within: mode == _SearchMode.document ? c.reading?.document.id : null,
    );
    if (!mounted || request != _searchRequest || mode != _searchMode) return;
    setState(() {
      _searchResults = results;
      _activeMatch = 0;
      _searching = false;
    });
  }

  DocumentSearchResult? _resultForCurrentDocument() {
    final id = c.reading?.document.id;
    if (id == null) return null;
    for (final result in _searchResults) {
      if (result.document.id == id) return result;
    }
    return null;
  }

  void _moveMatch(int delta) {
    final total = _resultForCurrentDocument()?.matches.length ?? 0;
    if (total == 0) return;
    setState(() => _activeMatch = (_activeMatch + delta) % total);
  }

  Future<void> _openSearchResult(DocumentSearchResult result, int match) async {
    _searchDebounce?.cancel();
    _searchRequest++;
    await c.openDocument(result.document.id);
    if (!mounted) return;
    setState(() {
      _searchMode = _SearchMode.document;
      _searchResults = [result];
      _activeMatch = match;
      _searching = false;
      _compactShelfVisible = false;
    });
  }

  Future<void> _followLink(String href) async {
    switch (c.resolveLink(href)) {
      case AnchorLink(:final anchor):
        _pane.currentState?.scrollToAnchor(anchor);
      case DocumentLink(:final id, :final anchor):
        await c.openDocument(id);
        if (_searchMode == _SearchMode.document) await _searchNow();
        if (anchor != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _pane.currentState?.scrollToAnchor(anchor);
          });
        }
      case ExternalLink(:final url):
        widget.openExternal(url);
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < _compactBreakpoint;

    void toggleShelf() {
      if (!compact) return c.toggleShelf();
      setState(() {
        _compactShelfVisible = !_compactShelfVisible;
        if (_compactShelfVisible) _compactOutlineVisible = false;
      });
    }

    void toggleOutline() {
      if (!compact) return c.toggleOutline();
      setState(() {
        _compactOutlineVisible = !_compactOutlineVisible;
        if (_compactOutlineVisible) _compactShelfVisible = false;
      });
    }

    void openLibrarySearch() {
      _openSearch(_SearchMode.library);
      if (compact) {
        setState(() {
          _compactShelfVisible = true;
          _compactOutlineVisible = false;
        });
      } else if (!c.shelfVisible) {
        c.toggleShelf();
      }
    }

    void dismissTransient() {
      if (_searchMode != _SearchMode.closed) {
        _closeSearch();
        return;
      }
      if (compact && (_compactShelfVisible || _compactOutlineVisible)) {
        setState(() {
          _compactShelfVisible = false;
          _compactOutlineVisible = false;
        });
      }
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyB, meta: true): toggleShelf,
        const SingleActivator(LogicalKeyboardKey.keyB, control: true):
            toggleShelf,
        const SingleActivator(LogicalKeyboardKey.period, meta: true):
            dismissTransient,
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true): () =>
            _openSearch(_SearchMode.document),
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () =>
            _openSearch(_SearchMode.document),
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true, shift: true):
            openLibrarySearch,
        const SingleActivator(
          LogicalKeyboardKey.keyF,
          control: true,
          shift: true,
        ): openLibrarySearch,
        const SingleActivator(LogicalKeyboardKey.keyG, meta: true): () =>
            _moveMatch(1),
        const SingleActivator(LogicalKeyboardKey.keyG, control: true): () =>
            _moveMatch(1),
        const SingleActivator(
          LogicalKeyboardKey.keyG,
          meta: true,
          shift: true,
        ): () =>
            _moveMatch(-1),
        const SingleActivator(
          LogicalKeyboardKey.keyG,
          control: true,
          shift: true,
        ): () =>
            _moveMatch(-1),
        // Text size. `=` carries the `+` on most keyboards, so both are bound.
        for (final key in [
          LogicalKeyboardKey.equal,
          LogicalKeyboardKey.add,
        ]) ...{
          SingleActivator(key, meta: true): c.enlargeText,
          SingleActivator(key, control: true): c.enlargeText,
        },
        for (final key in [
          LogicalKeyboardKey.minus,
          LogicalKeyboardKey.numpadSubtract,
        ]) ...{
          SingleActivator(key, meta: true): c.shrinkText,
          SingleActivator(key, control: true): c.shrinkText,
        },
        const SingleActivator(LogicalKeyboardKey.digit0, meta: true):
            c.resetText,
        const SingleActivator(LogicalKeyboardKey.digit0, control: true):
            c.resetText,
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true):
            c.newWorkspace,
        const SingleActivator(LogicalKeyboardKey.keyN, control: true):
            c.newWorkspace,
        ...switch (widget.openReaderSources) {
          final openReaderSources? => {
            const SingleActivator(LogicalKeyboardKey.keyO, meta: true):
                openReaderSources,
            const SingleActivator(LogicalKeyboardKey.keyO, control: true):
                openReaderSources,
          },
          null => {
            const SingleActivator(LogicalKeyboardKey.keyO, meta: true):
                c.pickAndAddFolder,
            const SingleActivator(LogicalKeyboardKey.keyO, control: true):
                c.pickAndAddFolder,
          },
        },
        const SingleActivator(LogicalKeyboardKey.keyO, meta: true, shift: true):
            c.openWorkspace,
        const SingleActivator(
          LogicalKeyboardKey.keyO,
          control: true,
          shift: true,
        ): c.openWorkspace,
        const SingleActivator(LogicalKeyboardKey.keyO, meta: true, alt: true):
            c.openSampleLibrary,
        const SingleActivator(
          LogicalKeyboardKey.keyO,
          control: true,
          alt: true,
        ): c.openSampleLibrary,
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true):
            c.saveWorkspace,
        const SingleActivator(LogicalKeyboardKey.keyS, control: true):
            c.saveWorkspace,
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true, shift: true):
            c.saveWorkspaceAs,
        const SingleActivator(
          LogicalKeyboardKey.keyS,
          control: true,
          shift: true,
        ): c.saveWorkspaceAs,
      },
      child: Focus(
        autofocus: true,
        child: ListenableBuilder(
          listenable: c,
          builder: (context, _) {
            final p = context.palette;
            final chrome = context.chrome;
            final library = c.library;
            final reading = c.reading;
            final toc = reading?.outline.tableOfContents;
            final hasOutline = toc != null && toc.isNotEmpty;
            final shelfVisible = compact
                ? _compactShelfVisible
                : c.shelfVisible;
            final outlineVisible = compact
                ? _compactOutlineVisible
                : c.outlineVisible;
            final showOutline = outlineVisible && hasOutline;
            // Side panels yield before the measured page does. The extra 96
            // logical pixels are the reading pane's wide-window gutters.
            final protectedCenter = reading == null
                ? 0.0
                : ReadingTheme.of(
                        context,
                        c.readingScale,
                      ).proseWidth(double.infinity) +
                      96;
            final fitted = c.panelWidths.fitWide(
              available: MediaQuery.sizeOf(context).width,
              protectedCenter: protectedCenter,
              // Fit against both panel preferences even while one is leaving,
              // so its child never changes width during the slide animation.
              shelfVisible: true,
              outlineVisible: hasOutline,
            );
            final sideBudget =
                MediaQuery.sizeOf(context).width - protectedCenter;
            final maximumShelfHere =
                (sideBudget - (hasOutline ? c.panelWidths.outline : 0)).clamp(
                  PanelWidths.minimumShelf,
                  PanelWidths.maximumShelf,
                );
            final maximumOutlineHere = (sideBudget - c.panelWidths.shelf).clamp(
              PanelWidths.minimumOutline,
              PanelWidths.maximumOutline,
            );
            final shelfWidth = compact
                ? c.panelWidths.shelfForCompact(
                    MediaQuery.sizeOf(context).width,
                  )
                : fitted.shelf;
            final outlineWidth = compact
                ? c.panelWidths.outlineForCompact(
                    MediaQuery.sizeOf(context).width,
                  )
                : fitted.outline;

            Widget readingPane() {
              if (reading == null) {
                return _EmptyLibrary(onOpenFolder: c.pickAndAddFolder);
              }
              final result = _resultForCurrentDocument();
              final pane = ReadingPane(
                key: _pane,
                reading: reading,
                scale: c.readingScale,
                codeHighlighter: widget.codeHighlighter,
                mermaidRenderer: widget.mermaidRenderer,
                imageLoader: widget.imageLoader,
                viewportGeometry: widget.viewportGeometry,
                matches: _searchMode == _SearchMode.document
                    ? result?.matches ?? const []
                    : const [],
                activeMatch: _searchMode == _SearchMode.document
                    ? _activeMatch
                    : -1,
                onLink: _followLink,
                onActiveHeadingChanged: (Heading? h) {
                  _activeAnchor.value = h?.anchor;
                },
              );
              if (_searchMode != _SearchMode.document) return pane;
              final total = result?.matches.length ?? 0;
              return Stack(
                children: [
                  Positioned.fill(child: pane),
                  Positioned(
                    top: 12,
                    right: 18,
                    child: DocumentFindBar(
                      controller: _searchText,
                      focusNode: _searchFocus,
                      onChanged: _searchChanged,
                      onNext: () => _moveMatch(1),
                      onPrevious: () => _moveMatch(-1),
                      onClose: _closeSearch,
                      active: _activeMatch,
                      total: total,
                      searching: _searching,
                    ),
                  ),
                ],
              );
            }

            Widget shelfPanel(bool visible) => CollapsiblePanel(
              visible: visible,
              width: shelfWidth,
              side: PanelSide.left,
              child: ColoredBox(
                color: chrome.panel,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _searchMode == _SearchMode.library
                          ? LibrarySearchPanel(
                              library: library!,
                              controller: _searchText,
                              focusNode: _searchFocus,
                              onChanged: _searchChanged,
                              onClose: _closeSearch,
                              results: _searchResults,
                              searching: _searching,
                              onSelect: _openSearchResult,
                            )
                          : ShelfPanel(
                              library: library!,
                              selected: reading?.document.id,
                              onSelect: (id) async {
                                await c.openDocument(id);
                                if (_searchMode == _SearchMode.document) {
                                  await _searchNow();
                                }
                                if (compact && mounted) {
                                  setState(() => _compactShelfVisible = false);
                                }
                              },
                              onOpenFolder: c.pickAndAddFolder,
                              onRemoveFolder: c.removeFolder,
                              onRemoveMarkdown: c.removeMarkdown,
                              onMoveFolder: c.moveFolder,
                              expandRequest: c.expandRequest,
                              workspace: c.workspaceSession?.workspace,
                              unavailableSources: c.unavailableSources,
                              onReconnectSource: c.reconnectSource,
                              onRemoveUnavailableSource:
                                  c.removeUnavailableSource,
                              labelMode: c.shelfLabelMode,
                              onLabelModeChanged: c.chooseShelfLabelMode,
                              sourceActions: widget.shelfSourceActions,
                            ),
                    ),
                    if (compact)
                      VerticalDivider(
                        width: 1,
                        thickness: 1,
                        color: chrome.separator,
                      )
                    else
                      PanelResizeHandle(
                        key: const ValueKey('shelf-resize-handle'),
                        panelName: 'shelf',
                        side: PanelSide.left,
                        width: shelfWidth,
                        onResizeBy: (delta) => c.previewShelfWidth(
                          (c.panelWidths.shelf + delta).clamp(
                            PanelWidths.minimumShelf,
                            maximumShelfHere,
                          ),
                        ),
                        onCommit: () => unawaited(c.rememberShelfWidth()),
                        onReset: () => unawaited(c.resetShelfWidth()),
                      ),
                  ],
                ),
              ),
            );

            Widget outlinePanel(bool visible) => CollapsiblePanel(
              visible: visible,
              width: outlineWidth,
              side: PanelSide.right,
              child: ColoredBox(
                color: chrome.panel,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (compact)
                      VerticalDivider(
                        width: 1,
                        thickness: 1,
                        color: chrome.separator,
                      )
                    else
                      PanelResizeHandle(
                        key: const ValueKey('outline-resize-handle'),
                        panelName: 'outline',
                        side: PanelSide.right,
                        width: outlineWidth,
                        onResizeBy: (delta) => c.previewOutlineWidth(
                          (c.panelWidths.outline + delta).clamp(
                            PanelWidths.minimumOutline,
                            maximumOutlineHere,
                          ),
                        ),
                        onCommit: () => unawaited(c.rememberOutlineWidth()),
                        onReset: () => unawaited(c.resetOutlineWidth()),
                      ),
                    Expanded(
                      child: ValueListenableBuilder<String?>(
                        valueListenable: _activeAnchor,
                        builder: (context, activeAnchor, _) => OutlinePanel(
                          tableOfContents: toc ?? const TableOfContents([]),
                          activeAnchor: activeAnchor,
                          onSelect: (h) {
                            _pane.currentState?.scrollToAnchor(h.anchor);
                            if (compact) {
                              setState(() => _compactOutlineVisible = false);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );

            return Scaffold(
              body: Stack(
                children: [
                  Column(
                    children: [
                      widget.windowDragRegion(
                        _TopBar(
                          height: widget.topBar.height,
                          leadingInset: widget.topBar.leadingInset,
                          shelfVisible: shelfVisible,
                          outlineVisible: outlineVisible,
                          hasLibrary: library != null,
                          documentTitle: reading?.document.title,
                          documentLocation: reading?.document.fileName,
                          onToggleShelf: toggleShelf,
                          onToggleOutline: toggleOutline,
                          onFind: reading == null
                              ? null
                              : () => _openSearch(_SearchMode.document),
                          themePicker: ThemePicker(
                            registry: c.themes,
                            choice: c.themeChoice,
                            onChoose: c.chooseTheme,
                            marking: c.readingScale.marking,
                            onMark: c.markParagraphs,
                            onOpenThemesFolder: widget.openThemesFolder,
                          ),
                        ),
                      ),
                      Expanded(
                        child: library == null
                            ? WelcomeView(
                                opening: c.opening,
                                error: c.error,
                                onOpen:
                                    widget.openReaderSources ??
                                    c.pickAndAddFolder,
                                onOpenWorkspace: c.openWorkspace,
                                onOpenSample: c.openSampleLibrary,
                                opensMixedSources:
                                    widget.openReaderSources != null,
                              )
                            : compact
                            ? Stack(
                                children: [
                                  Positioned.fill(child: readingPane()),
                                  if (shelfVisible || showOutline)
                                    Positioned.fill(
                                      child: GestureDetector(
                                        key: const ValueKey(
                                          'compact-panel-dismiss-region',
                                        ),
                                        behavior: HitTestBehavior.opaque,
                                        onTap: dismissTransient,
                                      ),
                                    ),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: shelfPanel(shelfVisible),
                                  ),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: outlinePanel(showOutline),
                                  ),
                                ],
                              )
                            : Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  shelfPanel(shelfVisible),
                                  Expanded(child: readingPane()),
                                  outlinePanel(showOutline),
                                ],
                              ),
                      ),
                    ],
                  ),
                  if (c.opening && library != null)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: LinearProgressIndicator(
                        minHeight: 2,
                        color: p.accent,
                        backgroundColor: Colors.transparent,
                      ),
                    ),
                  if (c.error != null && library != null)
                    Positioned(
                      top: widget.topBar.height + 12,
                      left: 12,
                      right: 12,
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ErrorNotice(
                          message: c.error!,
                          onDismiss: c.clearError,
                        ),
                      ),
                    ),
                  if (c.dragging) const Positioned.fill(child: DropOverlay()),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final double height;
  final double leadingInset;
  final bool shelfVisible;
  final bool outlineVisible;
  final bool hasLibrary;
  final String? documentTitle;
  final String? documentLocation;
  final VoidCallback onToggleShelf;
  final VoidCallback onToggleOutline;
  final VoidCallback? onFind;
  final Widget themePicker;

  const _TopBar({
    required this.height,
    required this.leadingInset,
    required this.shelfVisible,
    required this.outlineVisible,
    required this.hasLibrary,
    required this.documentTitle,
    required this.documentLocation,
    required this.onToggleShelf,
    required this.onToggleOutline,
    required this.onFind,
    required this.themePicker,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final chrome = context.chrome;
    return Container(
      height: height,
      padding: EdgeInsets.only(
        left: leadingInset,
        right: LibraryChromeScale.space2,
      ),
      decoration: BoxDecoration(
        color: chrome.topBar,
        border: Border(bottom: BorderSide(color: chrome.separator)),
      ),
      child: Row(
        children: [
          _BarButton(
            tooltip: shelfVisible ? 'Hide shelf  (⌘B)' : 'Show shelf  (⌘B)',
            icon: shelfVisible
                ? Icons.vertical_split
                : Icons.vertical_split_outlined,
            active: shelfVisible,
            onPressed: hasLibrary ? onToggleShelf : null,
          ),
          const SizedBox(width: LibraryChromeScale.space4),
          const BrandMark(size: 18),
          const SizedBox(width: LibraryChromeScale.space2),
          Text(
            'Visual MD',
            style: context.type.serif(
              color: p.ink,
              size: 15,
              weight: FontWeight.w600,
              height: 1,
            ),
          ),
          Expanded(
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 140),
                child: documentTitle == null
                    ? const SizedBox.shrink()
                    : Column(
                        key: ValueKey(documentLocation),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            documentTitle!,
                            key: const ValueKey('top-bar-document-title'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.chromeRow(
                              color: p.ink,
                              weight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            documentLocation!,
                            key: const ValueKey('top-bar-document-location'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.type.sans(
                              color: p.muted,
                              size: 10.5,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
          _BarButton(
            tooltip: 'Find in document  (⌘F)',
            icon: Icons.search,
            onPressed: onFind,
          ),
          const SizedBox(width: LibraryChromeScale.space1),
          themePicker,
          const SizedBox(width: LibraryChromeScale.space1),
          _BarButton(
            tooltip: outlineVisible ? 'Hide outline' : 'Show outline',
            icon: outlineVisible ? Icons.toc : Icons.toc_outlined,
            active: outlineVisible,
            onPressed: hasLibrary ? onToggleOutline : null,
          ),
        ],
      ),
    );
  }
}

class _BarButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  /// True when what the button controls is on screen.
  final bool active;

  const _BarButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Pressable(
      tooltip: tooltip,
      semanticLabel: tooltip.split('  (').first,
      onPress: onPressed,
      child: Padding(
        padding: const EdgeInsets.all(5),
        // The icon swaps as the panel comes and goes; cross-fading it keeps
        // the change as quiet as the panel's own movement.
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 140),
          transitionBuilder: (child, animation) =>
              FadeTransition(opacity: animation, child: child),
          child: Icon(
            icon,
            key: ValueKey(icon),
            size: 18,
            color: active ? p.accent : p.muted,
          ),
        ),
      ),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  final VoidCallback onOpenFolder;
  const _EmptyLibrary({required this.onOpenFolder});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'No markdown in this folder.',
            style: context.type.serif(
              color: p.ink,
              size: 22,
              weight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try another one — or drop it here.',
            style: context.type.sans(color: p.muted),
          ),
          const SizedBox(height: 18),
          OutlinedButton(
            onPressed: onOpenFolder,
            child: const Text('Open a folder'),
          ),
        ],
      ),
    );
  }
}
