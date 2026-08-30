import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../application/ports/document_image_loader.dart';
import '../../application/ports/document_viewport_geometry.dart';
import '../../application/use_cases/read_document.dart';
import '../../domain/reading/heading.dart';
import '../../domain/reading/content/block.dart';
import '../../domain/reading/content/document_content.dart';
import '../../domain/search/search_result.dart';
import '../../presentation/code/code_highlighter.dart';
import '../../application/ports/mermaid_renderer.dart';
import '../../presentation/theme/reading_scale.dart';
import '../../presentation/theme/reading_mode.dart';
import '../render/document_view.dart';
import '../render/reading_theme.dart';
import '../theme/library_theme.dart';
import 'quiet_scrollbar.dart';
import 'model_backed_selection_area.dart';
import 'windowed_paragraph.dart';

/// The page: one document, set by [DocumentView] and watched so the outline
/// knows where the reader is.
class ReadingPane extends StatefulWidget {
  final DocumentReading reading;
  final ReadingScale scale;
  final ReadingMode mode;
  final CodeHighlighter codeHighlighter;
  final MermaidRenderer mermaidRenderer;
  final DocumentImageLoader? imageLoader;
  final DocumentViewportGeometryFactory? viewportGeometry;
  final void Function(String href) onLink;
  final ValueChanged<Heading?> onActiveHeadingChanged;
  final ValueChanged<bool>? onSelectionAvailabilityChanged;
  final List<TextMatch> matches;
  final int activeMatch;

  /// Performance-harness hooks. Each value is the number of records visited
  /// by one navigation or render indexing pass.
  final ValueChanged<int>? debugOnNavigationBlocksIndexed;
  final ValueChanged<int>? debugOnRenderBlocksIndexed;
  final ValueChanged<int>? debugOnParagraphCodeUnitsIndexed;
  final ParagraphIndexStepObserver? debugOnParagraphInitialIndexStep;

  const ReadingPane({
    super.key,
    required this.reading,
    required this.scale,
    this.mode = ReadingMode.serif,
    this.codeHighlighter = const PlainCodeHighlighter(),
    this.mermaidRenderer = const UnavailableMermaidRenderer(),
    this.imageLoader,
    this.viewportGeometry,
    required this.onLink,
    required this.onActiveHeadingChanged,
    this.onSelectionAvailabilityChanged,
    this.matches = const [],
    this.activeMatch = -1,
    this.debugOnNavigationBlocksIndexed,
    this.debugOnRenderBlocksIndexed,
    this.debugOnParagraphCodeUnitsIndexed,
    this.debugOnParagraphInitialIndexStep,
  });

  @override
  State<ReadingPane> createState() => ReadingPaneState();
}

class ReadingPaneState extends State<ReadingPane> {
  /// A heading is "the one being read" once it has passed this far up the
  /// page — high enough to have been read, low enough not to jump ahead.
  static const _activeLine = 120.0;

  final _scroll = ScrollController();
  final _quietScrollbar = QuietScrollbarController();
  final _selection = ModelBackedSelectionController();
  final _pageKey = GlobalKey();
  final _documentSliverKey = GlobalKey();
  DocumentViewportGeometry? _geometry;
  var _keys = <String, GlobalKey>{};
  var _customKeys = <String, GlobalKey>{};
  var _matchKeys = <int, GlobalKey>{};
  var _headingIndexes = <String, int>{};
  var _headingOrder = <String, int>{};
  var _headingsByAnchor = <String, Heading>{};
  var _customAnchorIndexes = <String, int>{};
  var _blockOffsets = <int>[];
  var _visibleBlockIds = <DocumentBlockId>[];
  var _visibleBlockCount = 0;
  var _nextBlockOffset = 0;
  var _indexedOutlineHeadings = 0;
  final _mountedHeadings = <String>{};
  String? _activeAnchor;
  var _tailIntent = false;
  var _tailSettlementGeneration = 0;

  void copySelection() => _selection.copy();

  void selectAllText() => _selection.selectAll();

  @override
  void initState() {
    super.initState();
    _geometry = widget.viewportGeometry?.create();
    _indexNavigation();
    _scroll.addListener(_trackActiveHeading);
    WidgetsBinding.instance.addPostFrameCallback((_) => _trackActiveHeading());
  }

  @override
  void didUpdateWidget(ReadingPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    final documentChanged =
        oldWidget.reading.document.id != widget.reading.document.id;
    if (documentChanged ||
        !identical(oldWidget.viewportGeometry, widget.viewportGeometry)) {
      _geometry = widget.viewportGeometry?.create();
    }
    if (documentChanged) {
      _keys = {};
      _customKeys = {};
      _matchKeys = {};
      _mountedHeadings.clear();
      _activeAnchor = null;
      _indexNavigation();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.jumpTo(0);
        _trackActiveHeading();
      });
    } else if (!identical(oldWidget.reading.content, widget.reading.content)) {
      // The page changed beneath the same document identity. Rebuild heading
      // anchors, but keep the scroll controller exactly where the reader was.
      final tail = widget.reading.content.tailChangeSince(
        oldWidget.reading.content,
      );
      if (tail == null ||
          !_replaceNavigationTail(tail, oldWidget.reading.content)) {
        _resetNavigation();
      } else {
        final wasFollowingTail =
            _scroll.hasClients &&
            _scroll.position.maxScrollExtent - _scroll.position.pixels <= 1;
        if (wasFollowingTail) _settleAtTail();
      }
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _trackActiveHeading(),
      );
    } else if (oldWidget.reading.source != widget.reading.source) {
      _resetNavigation();
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _trackActiveHeading(),
      );
    }
    if (!identical(oldWidget.matches, widget.matches)) {
      _matchKeys = {};
    }
    if (oldWidget.activeMatch != widget.activeMatch ||
        !identical(oldWidget.matches, widget.matches)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToMatch());
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void scrollToAnchor(String anchor) {
    // An explicit author-supplied anchor is the least surprising target when
    // it happens to share a name with an automatically generated heading.
    final context = (_customKeys[anchor] ?? _keys[anchor])?.currentContext;
    if (context != null) {
      _ensureVisible(
        context,
        duration: const Duration(milliseconds: 320),
        alignment: 0,
      );
      return;
    }
    final index = _customAnchorIndexes[anchor] ?? _headingIndexes[anchor];
    if (index == null) return;
    _revealLazyBlock(
      index,
      () => (_customKeys[anchor] ?? _keys[anchor])?.currentContext,
      duration: const Duration(milliseconds: 320),
      alignment: 0,
    );
  }

  void _scrollToMatch() {
    final context = _matchKeys[widget.activeMatch]?.currentContext;
    if (context != null) {
      _ensureVisible(
        context,
        duration: const Duration(milliseconds: 220),
        alignment: 0.18,
      );
      return;
    }
    if (widget.activeMatch < 0 || widget.activeMatch >= widget.matches.length) {
      return;
    }
    final block = _blockForOffset(widget.matches[widget.activeMatch].start);
    _revealLazyBlock(
      block,
      () => _matchKeys[widget.activeMatch]?.currentContext,
      duration: const Duration(milliseconds: 220),
      alignment: 0.18,
    );
  }

  void _ensureVisible(
    BuildContext context, {
    required Duration duration,
    required double alignment,
  }) {
    Scrollable.ensureVisible(
      context,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : duration,
      curve: Curves.easeOutCubic,
      alignment: alignment,
    );
  }

  /// Materializes a lazy target from the geometry ledger, then lets Flutter
  /// align the real render box. The ledger seek does not scan or guess through
  /// the target's prefix; proportional placement remains only as the fallback
  /// for callers that did not install a viewport geometry adapter.
  void _revealLazyBlock(
    int index,
    BuildContext? Function() contextFor, {
    required Duration duration,
    required double alignment,
    int attempt = 0,
  }) {
    if (!_scroll.hasClients || _visibleBlockCount == 0) return;
    final fraction = index / _visibleBlockCount;
    final target =
        (_ledgerOffsetFor(index) ?? _scroll.position.maxScrollExtent * fraction)
            .clamp(
              _scroll.position.minScrollExtent,
              _scroll.position.maxScrollExtent,
            );
    _scroll.jumpTo(target);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final context = contextFor();
      if (context != null) {
        _ensureVisible(context, duration: duration, alignment: alignment);
      } else if (attempt < 2) {
        _revealLazyBlock(
          index,
          contextFor,
          duration: duration,
          alignment: alignment,
          attempt: attempt + 1,
        );
      }
    });
  }

  double? _ledgerOffsetFor(int index) {
    final geometry = _geometry;
    if (geometry == null || index < 0 || index >= geometry.length) return null;
    final renderSliver =
        _documentSliverKey.currentContext?.findRenderObject() as RenderSliver?;
    return (renderSliver?.constraints.precedingScrollExtent ?? 0) +
        geometry.leadingOffsetOf(_visibleBlockIds[index]);
  }

  DocumentBlockId? _viewportAnchor() {
    final geometry = _geometry;
    if (geometry == null || geometry.length == 0 || !_scroll.hasClients) {
      return null;
    }
    final renderSliver =
        _documentSliverKey.currentContext?.findRenderObject() as RenderSliver?;
    if (renderSliver == null) return null;
    final localOffset =
        _scroll.position.pixels -
        renderSliver.constraints.precedingScrollExtent;
    if (localOffset < 0) return null;
    return geometry.blockAtOffset(localOffset);
  }

  void _indexNavigation() {
    _headingIndexes = {};
    _headingOrder = {};
    _headingsByAnchor = {};
    _customAnchorIndexes = {};
    _blockOffsets = [];
    _visibleBlockIds = [];
    _visibleBlockCount = 0;
    _nextBlockOffset = 0;
    _indexedOutlineHeadings = 0;
    _appendNavigation(widget.reading.content.entries);
  }

  void _resetNavigation() {
    _keys = {};
    _customKeys = {};
    _matchKeys = {};
    _mountedHeadings.clear();
    _activeAnchor = null;
    _indexNavigation();
  }

  void _appendNavigation(List<DocumentBlock> entries) {
    widget.debugOnNavigationBlocksIndexed?.call(entries.length);
    final pendingAnchors = <String>[];
    for (final entry in entries) {
      final block = entry.block;
      if (block case AnchorBlock(:final name)) {
        pendingAnchors.add(name);
        continue;
      }
      for (final anchor in pendingAnchors) {
        _customAnchorIndexes.putIfAbsent(anchor, () => _visibleBlockCount);
      }
      pendingAnchors.clear();
      if (block case HeadingBlock(:final anchor)) {
        _headingIndexes[anchor] = _visibleBlockCount;
      }
      _blockOffsets.add(_nextBlockOffset);
      _visibleBlockIds.add(entry.id);
      _nextBlockOffset += entry.textMetrics.codeUnits + 2;
      _visibleBlockCount++;
    }
    for (final anchor in pendingAnchors) {
      _customAnchorIndexes.putIfAbsent(anchor, () => _visibleBlockCount);
    }

    final outlineHeadings = widget.reading.outline.tableOfContents.headings;
    if (_indexedOutlineHeadings > outlineHeadings.length) {
      _headingOrder = {};
      _headingsByAnchor = {};
      _indexedOutlineHeadings = 0;
    }
    for (
      var index = _indexedOutlineHeadings;
      index < outlineHeadings.length;
      index++
    ) {
      final heading = outlineHeadings[index];
      _headingOrder[heading.anchor] = index;
      _headingsByAnchor[heading.anchor] = heading;
    }
    _indexedOutlineHeadings = outlineHeadings.length;
  }

  bool _replaceNavigationTail(
    DocumentTailChange change,
    DocumentContent previous,
  ) {
    final removed = [
      for (var index = change.index; index < previous.entries.length; index++)
        previous.entries[index],
    ];
    bool changesNavigation(DocumentBlock entry) =>
        entry.block is AnchorBlock || entry.block is HeadingBlock;
    if (removed.any(changesNavigation) ||
        change.blocks.any(changesNavigation)) {
      return false;
    }

    final visibleStart = _visibleBlockCount - removed.length;
    if (visibleStart < 0) return false;
    _blockOffsets.removeRange(visibleStart, _blockOffsets.length);
    _visibleBlockIds.removeRange(visibleStart, _visibleBlockIds.length);
    _visibleBlockCount = visibleStart;
    if (visibleStart == 0) {
      _nextBlockOffset = 0;
    } else {
      DocumentBlock? preceding;
      for (var index = change.index - 1; index >= 0; index--) {
        final entry = previous.entries[index];
        if (entry.block is AnchorBlock) continue;
        preceding = entry;
        break;
      }
      if (preceding == null) return false;
      _nextBlockOffset =
          _blockOffsets.last + preceding.textMetrics.codeUnits + 2;
    }
    _appendNavigation(change.blocks);
    return true;
  }

  int _blockForOffset(int offset) {
    if (_blockOffsets.isEmpty) return 0;
    var low = 0;
    var high = _blockOffsets.length - 1;
    while (low <= high) {
      final middle = (low + high) >> 1;
      if (_blockOffsets[middle] <= offset) {
        low = middle + 1;
      } else {
        high = middle - 1;
      }
    }
    return high.clamp(0, _blockOffsets.length - 1);
  }

  void _trackActiveHeading() {
    final page = _pageKey.currentContext?.findRenderObject() as RenderBox?;
    if (page == null) return;
    final pageTop = page.localToGlobal(Offset.zero).dy;
    Heading? active;
    int? firstMountedOrder;
    for (final anchor in _mountedHeadings) {
      final heading = _headingsByAnchor[anchor];
      final box =
          _keys[anchor]?.currentContext?.findRenderObject() as RenderBox?;
      if (heading == null || box == null) continue;
      final order = _headingOrder[anchor]!;
      if (firstMountedOrder == null || order < firstMountedOrder) {
        firstMountedOrder = order;
      }
      final top = box.localToGlobal(Offset.zero).dy - pageTop;
      if (top <= _activeLine) {
        final activeOrder = active == null ? -1 : _headingOrder[active.anchor]!;
        if (order > activeOrder) active = heading;
      }
    }
    final headings = widget.reading.outline.tableOfContents.headings;
    if (active == null && firstMountedOrder != null && firstMountedOrder > 0) {
      active = headings[firstMountedOrder - 1];
    }
    active ??=
        _headingsByAnchor[_activeAnchor] ??
        (headings.isEmpty ? null : headings.first);
    if (active?.anchor != _activeAnchor) {
      _activeAnchor = active?.anchor;
      widget.onActiveHeadingChanged(active);
    }
  }

  void _headingMountChanged(String anchor, bool isMounted) {
    if (isMounted) {
      _mountedHeadings.add(anchor);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _trackActiveHeading();
      });
    } else {
      _mountedHeadings.remove(anchor);
    }
  }

  bool _trackTailIntent(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    switch (notification) {
      case ScrollStartNotification():
        _tailIntent = false;
        _tailSettlementGeneration++;
      case ScrollUpdateNotification(:final dragDetails)
          when dragDetails != null &&
              notification.metrics.pixels >=
                  notification.metrics.maxScrollExtent - 1:
        _tailIntent = true;
      case OverscrollNotification(:final overscroll) when overscroll > 0:
        _tailIntent = true;
      case ScrollEndNotification():
        if (_tailIntent) _settleAtTail();
        _tailIntent = false;
      default:
        break;
    }
    return false;
  }

  /// Keeps an existing follow-tail relationship through lazy layout.
  ///
  /// A sliver can refine its maximum after materialising the newly appended
  /// child, so one extra frame is allowed to converge. Readers above the tail
  /// never enter this path and retain their exact physical offset.
  void _settleAtTail([int remainingPasses = 8, int? settlementGeneration]) {
    final activeGeneration =
        settlementGeneration ?? ++_tailSettlementGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !_scroll.hasClients ||
          activeGeneration != _tailSettlementGeneration) {
        return;
      }
      final position = _scroll.position;
      final delta = position.maxScrollExtent - position.pixels;
      if (delta.abs() > 0.01) position.jumpTo(position.maxScrollExtent);
      // A geometry correction may land after this frame reports equality.
      // Keep the tail relationship alive through the bounded convergence
      // window rather than mistaking an intermediate maximum for the final one.
      if (remainingPasses > 0) {
        _settleAtTail(remainingPasses - 1, activeGeneration);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final reading = widget.reading;
    final theme = ReadingTheme.of(context, widget.scale, mode: widget.mode);
    final horizontalPadding = MediaQuery.sizeOf(context).width < 600
        ? 24.0
        : 48.0;
    // A document that never says its own name is given one, so the page is
    // never headless.
    final hasOwnTitle = reading.outline.tableOfContents.headings.any(
      (h) => h.level == 1,
    );
    final folder = reading.document.id.folderPath;

    return LayoutBuilder(
      builder: (context, constraints) {
        final column = theme.proseWidth(
          constraints.maxWidth - horizontalPadding * 2,
        );
        final page = NotificationListener<ScrollNotification>(
          onNotification: _trackTailIntent,
          child: ModelBackedSelectionArea(
            selectionIdentity: reading.document.id,
            wholeText: () => reading.content.text,
            controller: _selection,
            onSelectionAvailabilityChanged:
                widget.onSelectionAvailabilityChanged,
            child: CustomScrollView(
              key: _pageKey,
              controller: _scroll,
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    theme.line * 1.5,
                    horizontalPadding,
                    0,
                  ),
                  sliver: SliverToBoxAdapter(
                    // The breadcrumb and any stand-in title belong to the
                    // column, not the window: both hang off its left edge.
                    child: Center(
                      child: SizedBox(
                        width: column,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              folder.isEmpty
                                  ? reading.document.fileName
                                  : '${folder.replaceAll('/', '  ›  ')}  ›  ${reading.document.fileName}',
                              style: context.type
                                  .sans(
                                    color: p.muted,
                                    size: theme.scale.base * 0.7,
                                  )
                                  .copyWith(letterSpacing: 0.2),
                            ),
                            SizedBox(height: theme.line),
                            if (!hasOwnTitle) ...[
                              Text(
                                reading.document.title,
                                style: theme.heading(1),
                              ),
                              SizedBox(height: theme.blockGap),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  sliver: SliverDocumentView(
                    key: _documentSliverKey,
                    document: reading.document.id,
                    content: reading.content,
                    theme: theme,
                    codeHighlighter: widget.codeHighlighter,
                    mermaidRenderer: widget.mermaidRenderer,
                    imageLoader: widget.imageLoader,
                    anchorKeys: _keys,
                    customAnchorKeys: _customKeys,
                    matches: widget.matches,
                    activeMatch: widget.activeMatch,
                    matchKeys: _matchKeys,
                    onHeadingMount: _headingMountChanged,
                    debugOnBlocksIndexed: widget.debugOnRenderBlocksIndexed,
                    debugOnParagraphCodeUnitsIndexed:
                        widget.debugOnParagraphCodeUnitsIndexed,
                    debugOnParagraphInitialIndexStep:
                        widget.debugOnParagraphInitialIndexStep,
                    viewportGeometry: _geometry,
                    viewportAnchor: _viewportAnchor(),
                    onExtentCorrection: _quietScrollbar.absorb,
                    onTapLink: widget.onLink,
                  ),
                ),
                SliverToBoxAdapter(child: SizedBox(height: theme.line * 6)),
              ],
            ),
          ),
        );
        final viewportGeometry = widget.viewportGeometry;
        if (viewportGeometry == null) {
          return Scrollbar(controller: _scroll, child: page);
        }
        return QuietScrollbar(
          controller: _scroll,
          geometryFactory: viewportGeometry,
          epochController: _quietScrollbar,
          child: page,
        );
      },
    );
  }
}
