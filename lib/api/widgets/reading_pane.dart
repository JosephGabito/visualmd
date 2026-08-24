import 'package:flutter/material.dart';

import '../../application/use_cases/read_document.dart';
import '../../domain/reading/heading.dart';
import '../../domain/search/search_result.dart';
import '../../presentation/theme/reading_scale.dart';
import '../render/document_view.dart';
import '../render/reading_theme.dart';
import '../theme/library_theme.dart';

/// The page: one document, set by [DocumentView] and watched so the outline
/// knows where the reader is.
class ReadingPane extends StatefulWidget {
  final DocumentReading reading;
  final ReadingScale scale;
  final void Function(String href) onLink;
  final ValueChanged<Heading?> onActiveHeadingChanged;
  final List<TextMatch> matches;
  final int activeMatch;

  const ReadingPane({
    super.key,
    required this.reading,
    required this.scale,
    required this.onLink,
    required this.onActiveHeadingChanged,
    this.matches = const [],
    this.activeMatch = -1,
  });

  @override
  State<ReadingPane> createState() => ReadingPaneState();
}

class ReadingPaneState extends State<ReadingPane> {
  /// A heading is "the one being read" once it has passed this far up the
  /// page — high enough to have been read, low enough not to jump ahead.
  static const _activeLine = 120.0;

  final _scroll = ScrollController();
  final _pageKey = GlobalKey();
  var _keys = <String, GlobalKey>{};
  var _matchKeys = <int, GlobalKey>{};
  String? _activeAnchor;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_trackActiveHeading);
    WidgetsBinding.instance.addPostFrameCallback((_) => _trackActiveHeading());
  }

  @override
  void didUpdateWidget(ReadingPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reading.document.id != widget.reading.document.id) {
      _keys = {};
      _matchKeys = {};
      _activeAnchor = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.jumpTo(0);
        _trackActiveHeading();
      });
    } else if (oldWidget.reading.document.content !=
        widget.reading.document.content) {
      // The page changed beneath the same document identity. Rebuild heading
      // anchors, but keep the scroll controller exactly where the reader was.
      _keys = {};
      _matchKeys = {};
      _activeAnchor = null;
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
    final context = _keys[anchor]?.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      alignment: 0,
    );
  }

  void _scrollToMatch() {
    final context = _matchKeys[widget.activeMatch]?.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: 0.18,
    );
  }

  void _trackActiveHeading() {
    final page = _pageKey.currentContext?.findRenderObject() as RenderBox?;
    if (page == null) return;
    final pageTop = page.localToGlobal(Offset.zero).dy;
    Heading? active;
    for (final heading in widget.reading.outline.tableOfContents.headings) {
      final box =
          _keys[heading.anchor]?.currentContext?.findRenderObject()
              as RenderBox?;
      if (box == null) continue;
      final top = box.localToGlobal(Offset.zero).dy - pageTop;
      if (top <= _activeLine) {
        active = heading;
      } else {
        break;
      }
    }
    active ??= widget.reading.outline.tableOfContents.headings.isEmpty
        ? null
        : widget.reading.outline.tableOfContents.headings.first;
    if (active?.anchor != _activeAnchor) {
      _activeAnchor = active?.anchor;
      widget.onActiveHeadingChanged(active);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final reading = widget.reading;
    final theme = ReadingTheme.of(context, widget.scale);
    final horizontalPadding = MediaQuery.sizeOf(context).width < 600
        ? 24.0
        : 48.0;
    // A document that never says its own name is given one, so the page is
    // never headless.
    final hasOwnTitle = reading.outline.tableOfContents.headings.any(
      (h) => h.level == 1,
    );
    final folder = reading.document.id.folderPath;

    return Scrollbar(
      controller: _scroll,
      child: SingleChildScrollView(
        key: _pageKey,
        controller: _scroll,
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          theme.line * 1.5,
          horizontalPadding,
          theme.line * 6,
        ),
        child: SelectionArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // The breadcrumb and any stand-in title belong to the column, not
              // to the window: everything on the page hangs off one left edge.
              final column = theme.proseWidth(constraints.maxWidth);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
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
                          Text(reading.document.title, style: theme.heading(1)),
                          SizedBox(height: theme.blockGap),
                        ],
                      ],
                    ),
                  ),
                  DocumentView(
                    content: reading.content,
                    theme: theme,
                    anchorKeys: _keys,
                    matches: widget.matches,
                    activeMatch: widget.activeMatch,
                    matchKeys: _matchKeys,
                    onTapLink: widget.onLink,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
