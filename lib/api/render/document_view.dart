import 'dart:math' as math;

import 'package:flutter/material.dart' hide TableCell;
import 'package:flutter/rendering.dart';

import '../../application/ports/document_image_loader.dart';
import '../../application/ports/document_viewport_geometry.dart';
import '../../domain/library/document_id.dart';
import '../../domain/reading/content/block.dart';
import '../../domain/reading/content/document_content.dart';
import '../../domain/reading/content/inline.dart';
import '../../domain/search/search_result.dart';
import '../../presentation/code/code_highlighter.dart';
import '../../application/ports/mermaid_renderer.dart';
import '../../presentation/theme/hanging_punctuation.dart';
import '../../presentation/theme/reading_scale.dart';
import '../../presentation/theme/theme_palette.dart';
import '../../presentation/theme/widow_binding.dart';
import '../theme/library_chrome.dart';
import '../theme/reading_measure.dart';
import '../widgets/code_block.dart';
import '../widgets/math_expression.dart';
import '../widgets/mermaid_diagram.dart';
import 'inline_composer.dart';
import 'geometry_sliver_list.dart';
import 'reading_direction.dart';
import 'reading_theme.dart';

/// The rules a page of paragraphs is set by.
abstract final class ParagraphRules {
  /// A paragraph is indented only when it follows another paragraph.
  ///
  /// An indent signals a separation from the text above. The paragraph that
  /// opens a document or a section has nothing behind it to be separated
  /// from, and one resuming after a list, a quotation or a code block is
  /// already separated by the space that block leaves — indenting it too
  /// would be the same signal said twice.
  static bool indents(Block? previous, ParagraphMarking marking) =>
      marking == ParagraphMarking.indented && previous is ParagraphBlock;
}

/// Sets a document on the page.
///
/// The page is built block by block rather than handed to a general-purpose
/// renderer, because the two things a reader needs most cannot be expressed
/// in a style sheet:
///
/// * **Prose and code want different columns.** Prose is bound by the
///   measure — around 66 characters. Code is written in lines of its own
///   length and may not be re-wrapped, so it is given more room and scrolls
///   when it still does not fit.
/// * **The vertical rhythm is a rule, not a series of paddings.** Every gap
///   is cut from one line of body text and emitted after the block that owns
///   it. Nothing adds external space above itself.
/// * **Paragraphs are marked by one signal, not two.** See [ParagraphRules].
class DocumentView extends StatelessWidget {
  final DocumentId? document;
  final DocumentContent content;
  final ReadingTheme theme;
  final CodeHighlighter codeHighlighter;
  final MermaidRenderer mermaidRenderer;
  final DocumentImageLoader? imageLoader;

  /// Keys by heading anchor, so the outline can bring a heading into view.
  final Map<String, GlobalKey> anchorKeys;

  /// Keys by local anchor identity. Explicit HTML anchors and generated
  /// footnote targets share this namespace but stay out of the outline.
  final Map<String, GlobalKey> customAnchorKeys;

  final void Function(String href)? onTapLink;
  final List<TextMatch> matches;
  final int activeMatch;
  final Map<int, GlobalKey> matchKeys;

  DocumentView({
    super.key,
    this.document,
    required this.content,
    required this.theme,
    required this.anchorKeys,
    Map<String, GlobalKey>? customAnchorKeys,
    this.codeHighlighter = const PlainCodeHighlighter(),
    this.mermaidRenderer = const UnavailableMermaidRenderer(),
    this.imageLoader,
    this.onTapLink,
    this.matches = const [],
    this.activeMatch = -1,
    Map<int, GlobalKey>? matchKeys,
  }) : customAnchorKeys = customAnchorKeys ?? <String, GlobalKey>{},
       matchKeys = matchKeys ?? <int, GlobalKey>{};

  @override
  Widget build(BuildContext context) {
    final composer = InlineComposer(
      theme: theme,
      document: document,
      imageLoader: imageLoader,
      onTapLink: onTapLink,
      matches: matches,
      activeMatch: activeMatch,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        final prose = theme.proseWidth(available);
        final wide = theme.wideWidth(available);

        return _BlockSequence(
          blocks: content.blocks,
          theme: theme,
          composer: composer,
          codeHighlighter: codeHighlighter,
          mermaidRenderer: mermaidRenderer,
          keys: anchorKeys,
          customKeys: customAnchorKeys,
          matchKeys: matchKeys,
          // A fixed width, not a maximum: a code block's ground should span
          // its column rather than shrinking to the length of its shortest
          // line, and prose should wrap at the measure rather than at the
          // width of the paragraph that happens to be longest.
          widthFor: (block) => _widthFor(block, prose, wide),
        );
      },
    );
  }

  static double _widthFor(Block block, double prose, double wide) =>
      switch (block) {
        CodeBlock() || MathBlock() || MermaidBlock() || TableBlock() => wide,
        _ => prose,
      };
}

/// The viewport-bounded form of [DocumentView].
///
/// A document may contain thousands of top-level blocks, but a reader can see
/// only a small run of them. Building that run through a sliver keeps widget,
/// layout, paint, and semantics work proportional to the viewport instead of
/// the document. Containers inside one visible block remain atomic: their
/// internal rhythm and selection contracts are still owned by [_BlockView].
class SliverDocumentView extends StatefulWidget {
  final DocumentId? document;
  final DocumentContent content;
  final ReadingTheme theme;
  final CodeHighlighter codeHighlighter;
  final MermaidRenderer mermaidRenderer;
  final DocumentImageLoader? imageLoader;
  final Map<String, GlobalKey> anchorKeys;
  final Map<String, GlobalKey> customAnchorKeys;
  final void Function(String href)? onTapLink;
  final List<TextMatch> matches;
  final int activeMatch;
  final Map<int, GlobalKey> matchKeys;
  final void Function(String anchor, bool mounted)? onHeadingMount;
  final DocumentViewportGeometry? viewportGeometry;
  final ValueChanged<DocumentExtentCorrection>? onExtentCorrection;
  final DocumentBlockId? viewportAnchor;

  /// Reports how many source records an indexing pass visited. The profile
  /// harness uses this to prove an append does not revisit its prefix.
  final ValueChanged<int>? debugOnBlocksIndexed;

  SliverDocumentView({
    super.key,
    this.document,
    required this.content,
    required this.theme,
    required this.anchorKeys,
    Map<String, GlobalKey>? customAnchorKeys,
    this.codeHighlighter = const PlainCodeHighlighter(),
    this.mermaidRenderer = const UnavailableMermaidRenderer(),
    this.imageLoader,
    this.onTapLink,
    this.matches = const [],
    this.activeMatch = -1,
    Map<int, GlobalKey>? matchKeys,
    this.onHeadingMount,
    this.viewportGeometry,
    this.onExtentCorrection,
    this.viewportAnchor,
    this.debugOnBlocksIndexed,
  }) : customAnchorKeys = customAnchorKeys ?? <String, GlobalKey>{},
       matchKeys = matchKeys ?? <int, GlobalKey>{};

  @override
  State<SliverDocumentView> createState() => _SliverDocumentViewState();
}

class _SliverDocumentViewState extends State<SliverDocumentView> {
  late _IndexedBlocks _index = _initialIndex();
  Object? _layoutSignature;
  var _layoutRevision = 0;
  var _needsGeometryReset = true;
  PendingDocumentExtentCorrection? _pendingCorrection;

  _IndexedBlocks _initialIndex() {
    final entries = widget.content.entries;
    widget.debugOnBlocksIndexed?.call(entries.length);
    return _indexDocumentBlocks(entries);
  }

  @override
  void didUpdateWidget(SliverDocumentView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.viewportGeometry, widget.viewportGeometry)) {
      _needsGeometryReset = true;
      _layoutSignature = null;
      _layoutRevision = widget.viewportGeometry?.layoutRevision ?? 0;
    }
    if (!identical(oldWidget.content, widget.content)) {
      final appended = widget.content.appendedSince(oldWidget.content);
      if (appended == null) {
        _index = _initialIndex();
        _needsGeometryReset = true;
      } else if (appended.isNotEmpty) {
        widget.debugOnBlocksIndexed?.call(appended.length);
        _index = _appendDocumentBlocks(_index, appended);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final composer = InlineComposer(
      theme: widget.theme,
      document: widget.document,
      imageLoader: widget.imageLoader,
      onTapLink: widget.onTapLink,
      matches: widget.matches,
      activeMatch: widget.activeMatch,
    );

    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.crossAxisExtent;
        final prose = widget.theme.proseWidth(available);
        final wide = widget.theme.wideWidth(available);
        final geometry = widget.viewportGeometry;
        if (geometry != null) {
          _prepareGeometry(
            geometry,
            available,
            prose,
            wide,
            widget.viewportAnchor,
          );
        }

        Widget buildBlock(BuildContext context, int index) {
          final entry = _index.visible[index];
          final block = entry.block;
          final previous = index == 0 ? null : _index.visible[index - 1].block;
          final next = index + 1 < _index.visible.length
              ? _index.visible[index + 1].block
              : null;
          final followingSpace = widget.theme.spaceAfter(block, next);
          final view = _BlockView(
            block: block,
            theme: widget.theme,
            composer: composer,
            codeHighlighter: widget.codeHighlighter,
            mermaidRenderer: widget.mermaidRenderer,
            keys: widget.anchorKeys,
            customKeys: widget.customAnchorKeys,
            matchKeys: widget.matchKeys,
            offset: entry.offset,
            indent: ParagraphRules.indents(previous, widget.theme.scale.marking)
                ? widget.theme.indent
                : 0,
            followingSpace: followingSpace,
            reconcileContainer: true,
          );
          final width = DocumentView._widthFor(block, prose, wide);
          final positioned = Align(
            alignment: Alignment.topCenter,
            child: SizedBox(width: width, child: view),
          );
          final observed = block is HeadingBlock
              ? _MountObserver(
                  identity: block.anchor,
                  onChanged: widget.onHeadingMount,
                  child: positioned,
                )
              : positioned;
          return KeyedSubtree(
            key: ValueKey(entry.id!),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _withAnchorTargets(observed, [
                  ...entry.anchors,
                  ..._footnoteReferenceAnchors(block),
                ], widget.customAnchorKeys),
                if (followingSpace > 0) SizedBox(height: followingSpace),
              ],
            ),
          );
        }

        int? findChildIndex(Key key) => switch (key) {
          ValueKey<DocumentBlockId>(:final value) =>
            _index.visibleIndexes[value],
          _ => null,
        };

        final list = geometry == null
            ? SliverList.builder(
                findChildIndexCallback: findChildIndex,
                itemCount: _index.visible.length,
                itemBuilder: buildBlock,
              )
            : GeometrySliverList.builder(
                viewportGeometry: geometry,
                layoutRevision: _layoutRevision,
                itemCount: _index.visible.length,
                seedAt: (index) => _seedFor(index, prose, wide),
                indexOf: (id) => _index.visibleIndexes[id]!,
                findChildIndexCallback: findChildIndex,
                itemBuilder: buildBlock,
                onExtentCorrection: widget.onExtentCorrection,
                pendingCorrection: _pendingCorrection,
              );
        if (_index.trailingAnchors.isEmpty) return list;
        return SliverMainAxisGroup(
          slivers: [
            list,
            SliverToBoxAdapter(
              child: _withAnchorTargets(
                const SizedBox.shrink(),
                _index.trailingAnchors,
                widget.customAnchorKeys,
              ),
            ),
          ],
        );
      },
    );
  }

  void _prepareGeometry(
    DocumentViewportGeometry geometry,
    double available,
    double prose,
    double wide,
    DocumentBlockId? anchor,
  ) {
    final signature = (
      available,
      prose,
      wide,
      widget.theme.line,
      widget.theme.renderedBase,
      widget.theme.body.fontFamily,
      widget.theme.scale.marking,
    );
    if (_layoutSignature != null && _layoutSignature != signature) {
      _layoutRevision = math.max(
        _layoutRevision + 1,
        geometry.layoutRevision + 1,
      );
    }
    _layoutSignature = signature;

    if (_needsGeometryReset || geometry.length > _index.visible.length) {
      final correction = geometry.reset(
        [
          for (var index = 0; index < _index.visible.length; index++)
            _seedFor(index, prose, wide),
        ],
        layoutRevision: _layoutRevision,
        anchor: anchor,
      );
      if (correction.contentExtentDelta != 0 ||
          correction.scrollOffsetDelta != 0) {
        _pendingCorrection = PendingDocumentExtentCorrection(correction);
      }
      _needsGeometryReset = false;
      return;
    }
    if (geometry.length < _index.visible.length) {
      geometry.appendAll([
        for (
          var index = geometry.length;
          index < _index.visible.length;
          index++
        )
          _seedFor(index, prose, wide),
      ]);
    }
  }

  DocumentExtentSeed _seedFor(int index, double prose, double wide) {
    final entry = _index.visible[index];
    final next = index + 1 < _index.visible.length
        ? _index.visible[index + 1].block
        : null;
    final block = entry.block;
    final width = DocumentView._widthFor(block, prose, wide);
    return DocumentExtentSeed(
      id: entry.id!,
      revision: entry.revision,
      estimatedExtent:
          _estimatedBlockExtent(block, width) +
          widget.theme.spaceAfter(block, next),
    );
  }

  double _estimatedBlockExtent(Block block, double width) {
    final theme = widget.theme;
    final averageAdvance = math.max(theme.renderedBase * 0.52, 1.0);
    final charactersPerLine = math.max((width / averageAdvance).floor(), 12);
    int wrappedLines(String text) => text
        .split('\n')
        .fold(
          0,
          (sum, line) =>
              sum + math.max(1, (line.length / charactersPerLine).ceil()),
        );

    return switch (block) {
      HeadingBlock(:final level, :final text) => math.max(
        theme.line,
        wrappedLines(text) *
            (theme.heading(level).fontSize ?? theme.renderedBase) *
            (theme.heading(level).height ?? 1.2),
      ),
      CodeBlock(:final code) =>
        math.max(2, code.split('\n').length + 1) * theme.line,
      MathBlock() => theme.line * 4,
      MermaidBlock() => theme.line * 8,
      _ => math.max(theme.line, wrappedLines(block.text) * theme.line),
    };
  }
}

class _MountObserver extends StatefulWidget {
  const _MountObserver({
    required this.identity,
    required this.onChanged,
    required this.child,
  });

  final String identity;
  final void Function(String identity, bool mounted)? onChanged;
  final Widget child;

  @override
  State<_MountObserver> createState() => _MountObserverState();
}

class _MountObserverState extends State<_MountObserver> {
  @override
  void initState() {
    super.initState();
    widget.onChanged?.call(widget.identity, true);
  }

  @override
  void didUpdateWidget(_MountObserver oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.identity != widget.identity ||
        oldWidget.onChanged != widget.onChanged) {
      oldWidget.onChanged?.call(oldWidget.identity, false);
      widget.onChanged?.call(widget.identity, true);
    }
  }

  @override
  void dispose() {
    widget.onChanged?.call(widget.identity, false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Sets a run of blocks from top to bottom.
///
/// Every external gap is emitted after the block that owns it. The same rule
/// applies at every depth, so a quotation or list item cannot introduce a
/// second spacing convention of its own.
class _BlockSequence extends StatelessWidget {
  final List<Block> blocks;
  final ReadingTheme theme;
  final InlineComposer composer;
  final CodeHighlighter codeHighlighter;
  final MermaidRenderer mermaidRenderer;
  final Map<String, GlobalKey> keys;
  final Map<String, GlobalKey> customKeys;
  final Map<int, GlobalKey> matchKeys;
  final double Function(Block block)? widthFor;
  final int startOffset;
  final int separatorLength;
  final double Function(Block current, Block? next)? spaceAfter;
  final bool reconcileContainers;

  const _BlockSequence({
    required this.blocks,
    required this.theme,
    required this.composer,
    required this.codeHighlighter,
    required this.mermaidRenderer,
    required this.keys,
    required this.customKeys,
    required this.matchKeys,
    this.widthFor,
    this.startOffset = 0,
    this.separatorLength = 2,
    this.spaceAfter,
    this.reconcileContainers = true,
  });

  @override
  Widget build(BuildContext context) {
    final marking = theme.scale.marking;
    final children = <Widget>[];
    final index = _indexBlocks(
      blocks,
      startOffset: startOffset,
      separatorLength: separatorLength,
    );
    final visible = index.visible;

    for (var i = 0; i < visible.length; i++) {
      final entry = visible[i];
      final block = entry.block;
      final previous = i == 0 ? null : visible[i - 1].block;
      final next = i + 1 < visible.length ? visible[i + 1].block : null;
      final followingSpace =
          spaceAfter?.call(block, next) ?? theme.spaceAfter(block, next);

      final view = _BlockView(
        block: block,
        theme: theme,
        composer: composer,
        codeHighlighter: codeHighlighter,
        mermaidRenderer: mermaidRenderer,
        keys: keys,
        customKeys: customKeys,
        matchKeys: matchKeys,
        offset: entry.offset,
        indent: ParagraphRules.indents(previous, marking) ? theme.indent : 0,
        followingSpace: followingSpace,
        reconcileContainer: reconcileContainers,
      );
      final width = widthFor?.call(block);
      final positioned = width == null
          ? view
          : Align(
              alignment: Alignment.topCenter,
              child: SizedBox(width: width, child: view),
            );
      children.add(
        _withAnchorTargets(positioned, [
          ...entry.anchors,
          ..._footnoteReferenceAnchors(block),
        ], customKeys),
      );
      if (followingSpace > 0) {
        children.add(SizedBox(height: followingSpace));
      }
    }
    if (index.trailingAnchors.isNotEmpty) {
      children.add(
        _withAnchorTargets(
          const SizedBox.shrink(),
          index.trailingAnchors,
          customKeys,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

final class _VisibleBlock {
  const _VisibleBlock(
    this.block,
    this.anchors,
    this.offset,
    this.id,
    this.revision,
  );

  final Block block;
  final List<String> anchors;
  final int offset;
  final DocumentBlockId? id;
  final int revision;
}

final class _IndexedBlocks {
  const _IndexedBlocks({
    required this.visible,
    required this.trailingAnchors,
    required this.claimedAnchors,
    required this.nextOffset,
    required this.visibleIndexes,
  });

  final List<_VisibleBlock> visible;
  final List<String> trailingAnchors;
  final Set<String> claimedAnchors;
  final int nextOffset;
  final Map<DocumentBlockId, int> visibleIndexes;
}

_IndexedBlocks _indexBlocks(
  List<Block> blocks, {
  int startOffset = 0,
  int separatorLength = 2,
}) {
  return _extendIndex(_emptyIndex(startOffset), [
    for (final block in blocks) (block: block, id: null, revision: 0),
  ], separatorLength: separatorLength);
}

_IndexedBlocks _indexDocumentBlocks(
  List<DocumentBlock> blocks, {
  int startOffset = 0,
  int separatorLength = 2,
}) => _extendIndex(_emptyIndex(startOffset), [
  for (final entry in blocks)
    (block: entry.block, id: entry.id, revision: entry.revision),
], separatorLength: separatorLength);

_IndexedBlocks _appendDocumentBlocks(
  _IndexedBlocks current,
  List<DocumentBlock> appended, {
  int separatorLength = 2,
}) => _extendIndex(current, [
  for (final entry in appended)
    (block: entry.block, id: entry.id, revision: entry.revision),
], separatorLength: separatorLength);

_IndexedBlocks _emptyIndex(int startOffset) => _IndexedBlocks(
  visible: const [],
  trailingAnchors: const [],
  claimedAnchors: const {},
  nextOffset: startOffset,
  visibleIndexes: const {},
);

_IndexedBlocks _extendIndex(
  _IndexedBlocks current,
  List<({Block block, DocumentBlockId? id, int revision})> appended, {
  required int separatorLength,
}) {
  final visible = current.visible.toList();
  final pendingAnchors = current.trailingAnchors.toList();
  final claimedAnchors = current.claimedAnchors.toSet();
  final visibleIndexes = Map<DocumentBlockId, int>.of(current.visibleIndexes);
  var offset = current.nextOffset;
  for (final entry in appended) {
    final block = entry.block;
    if (block case AnchorBlock(:final name)) {
      if (claimedAnchors.add(name)) pendingAnchors.add(name);
      continue;
    }
    final visibleIndex = visible.length;
    final id = entry.id;
    if (id != null) visibleIndexes[id] = visibleIndex;
    visible.add(
      _VisibleBlock(block, List.of(pendingAnchors), offset, id, entry.revision),
    );
    pendingAnchors.clear();
    offset += block.text.length + separatorLength;
  }
  return _IndexedBlocks(
    visible: List.unmodifiable(visible),
    trailingAnchors: List.unmodifiable(pendingAnchors),
    claimedAnchors: Set.unmodifiable(claimedAnchors),
    nextOffset: offset,
    visibleIndexes: Map.unmodifiable(visibleIndexes),
  );
}

Widget _withAnchorTargets(
  Widget child,
  Iterable<String> anchors,
  Map<String, GlobalKey> keys,
) {
  var target = child;
  for (final anchor in anchors) {
    target = KeyedSubtree(
      key: keys.putIfAbsent(anchor, GlobalKey.new),
      child: target,
    );
  }
  return target;
}

class _BlockView extends StatelessWidget {
  final Block block;
  final ReadingTheme theme;
  final InlineComposer composer;
  final CodeHighlighter codeHighlighter;
  final MermaidRenderer mermaidRenderer;
  final Map<String, GlobalKey> keys;
  final Map<String, GlobalKey> customKeys;
  final Map<int, GlobalKey> matchKeys;
  final int offset;
  final double followingSpace;
  final bool reconcileContainer;

  /// The first-line indent this paragraph is set with; 0 for every other kind
  /// of block, and for a paragraph that opens a document or a section.
  final double indent;

  const _BlockView({
    required this.block,
    required this.theme,
    required this.composer,
    required this.codeHighlighter,
    required this.mermaidRenderer,
    required this.keys,
    required this.customKeys,
    required this.matchKeys,
    required this.offset,
    required this.followingSpace,
    required this.reconcileContainer,
    this.indent = 0,
  });

  @override
  Widget build(BuildContext context) {
    switch (block) {
      case ParagraphBlock(:final content):
        // The style comes from the theme in hand, which inside a quotation is
        // the quoting one.
        final paragraph = Paragraph(
          spans: composer.compose(content, style: theme.body, offset: offset),
          style: theme.body,
          textScaler: theme.textScaler,
          strut: theme.strutFor(theme.body),
          indent: indent,
        );
        return _matchTarget(
          reconcileContainer && content.any(_containsMath)
              ? _RhythmicContainer(
                  beat: theme.baseline,
                  followingSpace: followingSpace,
                  child: paragraph,
                )
              : paragraph,
        );

      case HeadingBlock(:final level, :final content, :final anchor):
        return _matchTarget(
          KeyedSubtree(
            key: keys.putIfAbsent(anchor, GlobalKey.new),
            child: _RhythmicHeading(
              beat: theme.baseline,
              followingSpace: followingSpace,
              child: Semantics(
                header: true,
                headingLevel: level,
                child: Text.rich(
                  TextSpan(
                    children: composer.compose(
                      content,
                      style: theme.heading(level),
                      offset: offset,
                    ),
                  ),
                  textDirection: ReadingDirection.of(
                    content.map((run) => run.text).join(),
                    fallback: Directionality.of(context),
                  ),
                ),
              ),
            ),
          ),
        );

      case AnchorBlock():
        return const SizedBox.shrink();

      case CodeBlock(:final code, :final language):
        return _matchTarget(
          ReadableCodeBlock(
            source: code,
            language: language,
            highlighter: codeHighlighter,
            scheme: Theme.of(context).brightness == Brightness.dark
                ? CodeHighlightScheme.dark
                : CodeHighlightScheme.light,
            spansFor: (highlighting) => composer.highlightedVerbatim(
              code,
              style: theme.code,
              highlighting: highlighting,
              styleFor: theme.codeToken,
              offset: offset,
            ),
            textStyle: theme.code,
            bodyBackground: theme.codeBodyBackground,
            beat: theme.baseline,
            // The header keeps the prose beat while source lines run more
            // tightly beneath it. The body reconciles the completed surface,
            // rather than forcing each source line onto the prose grid.
            headerHeight: theme.baseline,
            padding: EdgeInsets.symmetric(
              horizontal: theme.renderedBase * 0.9,
              vertical: theme.codeLine / 2,
            ),
            // Its own ground is enough to say what it is; a border as well
            // would be the same signal twice, and a border has a height.
            decoration: BoxDecoration(
              color: theme.palette.codeBackground,
              borderRadius: BorderRadius.circular(
                LibraryChromeScale.componentRadius,
              ),
            ),
          ),
        );

      case MathBlock(:final source):
        final equation = ReadableMathBlock(source: source, theme: theme);
        return _matchTarget(
          reconcileContainer
              ? _RhythmicContainer(
                  beat: theme.baseline,
                  followingSpace: followingSpace,
                  child: equation,
                )
              : equation,
        );

      case MermaidBlock(:final source):
        final diagram = ReadableMermaidDiagram(
          source: source,
          renderer: mermaidRenderer,
          palette: MermaidPalette(
            canvas: ThemePalette.hex(theme.palette.paper),
            surface: ThemePalette.hex(theme.palette.panel),
            text: ThemePalette.hex(theme.palette.ink),
            subtleText: ThemePalette.hex(theme.palette.muted),
            border: ThemePalette.hex(theme.palette.border),
            line: ThemePalette.hex(theme.palette.muted),
            accent: ThemePalette.hex(theme.palette.accent),
            dark: theme.isDark,
          ),
          beat: theme.baseline,
        );
        return _matchTarget(
          reconcileContainer
              ? _RhythmicContainer(
                  beat: theme.baseline,
                  followingSpace: followingSpace,
                  child: diagram,
                )
              : diagram,
        );

      case QuoteBlock(:final blocks):
        return _Quote(
          blocks: blocks,
          theme: theme,
          composer: composer,
          codeHighlighter: codeHighlighter,
          mermaidRenderer: mermaidRenderer,
          keys: keys,
          customKeys: customKeys,
          matchKeys: matchKeys,
          offset: offset,
          followingSpace: followingSpace,
          reconcile: reconcileContainer,
        );

      case ListBlock():
        return _List(
          list: block as ListBlock,
          theme: theme,
          composer: composer,
          codeHighlighter: codeHighlighter,
          mermaidRenderer: mermaidRenderer,
          keys: keys,
          customKeys: customKeys,
          matchKeys: matchKeys,
          offset: offset,
          followingSpace: followingSpace,
          reconcile: reconcileContainer,
        );

      case FootnoteSectionBlock():
        return _Footnotes(
          section: block as FootnoteSectionBlock,
          theme: theme,
          composer: composer,
          codeHighlighter: codeHighlighter,
          mermaidRenderer: mermaidRenderer,
          keys: keys,
          customKeys: customKeys,
          matchKeys: matchKeys,
          offset: offset,
          followingSpace: followingSpace,
          reconcile: reconcileContainer,
        );

      case TableBlock():
        final table = _Table(
          table: block as TableBlock,
          theme: theme,
          composer: composer,
          offset: offset,
        );
        return _matchTarget(
          _RhythmicContainer(
            beat: theme.baseline,
            followingSpace: followingSpace,
            child: table,
          ),
        );

      case RuleBlock():
        return Semantics(
          container: true,
          label: 'Thematic break',
          child: SizedBox(
            height: theme.baseline,
            child: Center(
              child: Divider(
                height: 1,
                thickness: 1,
                color: theme.palette.border,
              ),
            ),
          ),
        );

      case RawBlock(:final text):
        return _matchTarget(
          Text.rich(
            TextSpan(
              children: composer.verbatim(
                text,
                style: theme.body.copyWith(color: theme.palette.muted),
                offset: offset,
              ),
            ),
            textDirection: ReadingDirection.of(
              text,
              fallback: Directionality.of(context),
            ),
          ),
        );
    }
  }

  Widget _matchTarget(Widget child) {
    final indexes = [
      for (var i = 0; i < composer.matches.length; i++)
        if (composer.matches[i].overlaps(offset, offset + block.text.length)) i,
    ];
    if (indexes.isEmpty) return child;
    final key = GlobalKey();
    for (final index in indexes) {
      matchKeys[index] = key;
    }
    return KeyedSubtree(key: key, child: child);
  }
}

bool _containsMath(Inline inline) => switch (inline) {
  MathRun() => true,
  MarkedRun(:final children) ||
  LinkRun(:final children) => children.any(_containsMath),
  _ => false,
};

Iterable<String> _footnoteReferenceAnchors(Block block) sync* {
  Iterable<String> inlines(Iterable<Inline> content) sync* {
    for (final inline in content) {
      switch (inline) {
        case FootnoteReferenceRun(
          :final referenceAnchor,
          :final ownsReferenceAnchor,
        ):
          if (ownsReferenceAnchor) yield referenceAnchor;
        case MarkedRun(:final children) || LinkRun(:final children):
          yield* inlines(children);
        default:
          continue;
      }
    }
  }

  switch (block) {
    case ParagraphBlock(:final content) || HeadingBlock(:final content):
      yield* inlines(content);
    case TableBlock(:final head, :final rows):
      for (final cell in [...head, ...rows.expand((row) => row)]) {
        yield* inlines(cell.content);
      }
    default:
      // Recursive containers build their own `_BlockSequence`; that inner
      // sequence owns each reference key at the block that paints it. Claiming
      // the same key here would both relocate the return target and put one
      // GlobalKey in two places in the tree.
      return;
  }
}

/// The document's notes: one quiet rule, then an ordered annotation column.
///
/// Definitions use the same block renderer as the document rather than a
/// second Markdown surface. Their smaller theme changes only the typographic
/// role; the outer rhythmic container returns the completed section to the
/// running page's baseline.
class _Footnotes extends StatelessWidget {
  final FootnoteSectionBlock section;
  final ReadingTheme theme;
  final InlineComposer composer;
  final CodeHighlighter codeHighlighter;
  final MermaidRenderer mermaidRenderer;
  final Map<String, GlobalKey> keys;
  final Map<String, GlobalKey> customKeys;
  final Map<int, GlobalKey> matchKeys;
  final int offset;
  final double followingSpace;
  final bool reconcile;

  const _Footnotes({
    required this.section,
    required this.theme,
    required this.composer,
    required this.codeHighlighter,
    required this.mermaidRenderer,
    required this.keys,
    required this.customKeys,
    required this.matchKeys,
    required this.offset,
    required this.followingSpace,
    required this.reconcile,
  });

  @override
  Widget build(BuildContext context) {
    final notesTheme = ReadingTheme.footnotes(theme);
    final notesComposer = InlineComposer(
      theme: notesTheme,
      document: composer.document,
      imageLoader: composer.imageLoader,
      onTapLink: composer.onTapLink,
      matches: composer.matches,
      activeMatch: composer.activeMatch,
    );
    final notes = ListBlock(
      ordered: true,
      loose: true,
      items: [
        for (final definition in section.definitions)
          ListItem([
            if (definition.ownsAnchor) AnchorBlock(definition.anchor),
            ...definition.blocks,
          ]),
      ],
    );
    final content = Container(
      padding: EdgeInsets.only(top: theme.containerGap),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.palette.border)),
      ),
      child: _List(
        list: notes,
        theme: notesTheme,
        composer: notesComposer,
        codeHighlighter: codeHighlighter,
        mermaidRenderer: mermaidRenderer,
        keys: keys,
        customKeys: customKeys,
        matchKeys: matchKeys,
        offset: offset,
        followingSpace: 0,
        reconcile: false,
      ),
    );
    if (!reconcile) return content;
    return _RhythmicContainer(
      beat: theme.baseline,
      followingSpace: followingSpace,
      child: content,
    );
  }
}

/// Lets display lines use their natural leading, then reconciles the completed
/// heading with the running-text grid.
///
/// [_BlockSequence] owns the external [followingSpace]. This render object
/// accounts for that known outgoing gap and places only the remaining rhythm
/// correction before the heading. It therefore owns no inter-block spacing.
final class _RhythmicHeading extends SingleChildRenderObjectWidget {
  final double beat;
  final double followingSpace;

  const _RhythmicHeading({
    required this.beat,
    required this.followingSpace,
    required super.child,
  });

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderRhythmicHeading(beat, followingSpace);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderRhythmicHeading renderObject,
  ) {
    renderObject
      ..beat = beat
      ..followingSpace = followingSpace;
  }
}

final class _RenderRhythmicHeading extends RenderShiftedBox {
  _RenderRhythmicHeading(this._beat, this._followingSpace, [RenderBox? child])
    : super(child);

  double _beat;
  double get beat => _beat;
  set beat(double value) {
    if (_beat == value) return;
    _beat = value;
    markNeedsLayout();
  }

  double _followingSpace;
  double get followingSpace => _followingSpace;
  set followingSpace(double value) {
    if (_followingSpace == value) return;
    _followingSpace = value;
    markNeedsLayout();
  }

  BoxConstraints _childConstraints(BoxConstraints constraints) =>
      constraints.copyWith(minHeight: 0, maxHeight: double.infinity);

  double _reconciledHeight(double childHeight) =>
      _ceilToBeat(childHeight + followingSpace, beat) - followingSpace;

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final childSize = child?.getDryLayout(_childConstraints(constraints));
    if (childSize == null) return constraints.smallest;
    return constraints.constrain(
      Size(childSize.width, _reconciledHeight(childSize.height)),
    );
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }

    child.layout(_childConstraints(constraints), parentUsesSize: true);
    size = constraints.constrain(
      Size(child.size.width, _reconciledHeight(child.size.height)),
    );

    final childParentData = child.parentData! as BoxParentData;
    childParentData.offset = Offset(0, size.height - child.size.height);
  }
}

/// A quotation: set in the reader's own voice, marked once by a rule.
class _Quote extends StatelessWidget {
  final List<Block> blocks;
  final ReadingTheme theme;
  final InlineComposer composer;
  final CodeHighlighter codeHighlighter;
  final MermaidRenderer mermaidRenderer;
  final Map<String, GlobalKey> keys;
  final Map<String, GlobalKey> customKeys;
  final Map<int, GlobalKey> matchKeys;
  final int offset;
  final double followingSpace;
  final bool reconcile;

  const _Quote({
    required this.blocks,
    required this.theme,
    required this.composer,
    required this.codeHighlighter,
    required this.mermaidRenderer,
    required this.keys,
    required this.customKeys,
    required this.matchKeys,
    required this.offset,
    required this.followingSpace,
    required this.reconcile,
  });

  @override
  Widget build(BuildContext context) {
    final quoted = ReadingTheme.quoting(theme);
    final direction = ReadingDirection.of(
      blocks.map((block) => block.text).join('\n'),
      fallback: Directionality.of(context),
    );
    final content = Container(
      padding: EdgeInsetsDirectional.only(start: theme.em),
      decoration: BoxDecoration(
        border: BorderDirectional(
          start: BorderSide(
            color: theme.palette.accent.withValues(alpha: 0.5),
            width: 2,
          ),
        ),
      ),
      child: _BlockSequence(
        blocks: blocks,
        theme: quoted,
        composer: composer,
        codeHighlighter: codeHighlighter,
        mermaidRenderer: mermaidRenderer,
        keys: keys,
        customKeys: customKeys,
        matchKeys: matchKeys,
        startOffset: offset,
        separatorLength: 1,
        spaceAfter: (current, next) =>
            theme.spaceAfterInContainer(current, next, tight: false),
        reconcileContainers: false,
      ),
    );
    return Directionality(
      textDirection: direction,
      child: reconcile
          ? _RhythmicContainer(
              beat: theme.baseline,
              followingSpace: followingSpace,
              child: content,
            )
          : content,
    );
  }
}

/// A list, with its markers hanging in the margin so the text of every item
/// starts on the same line.
class _List extends StatelessWidget {
  final ListBlock list;
  final ReadingTheme theme;
  final InlineComposer composer;
  final CodeHighlighter codeHighlighter;
  final MermaidRenderer mermaidRenderer;
  final Map<String, GlobalKey> keys;
  final Map<String, GlobalKey> customKeys;
  final Map<int, GlobalKey> matchKeys;
  final int offset;
  final double followingSpace;
  final bool reconcile;

  const _List({
    required this.list,
    required this.theme,
    required this.composer,
    required this.codeHighlighter,
    required this.mermaidRenderer,
    required this.keys,
    required this.customKeys,
    required this.matchKeys,
    required this.offset,
    required this.followingSpace,
    required this.reconcile,
  });

  @override
  Widget build(BuildContext context) {
    final gutter = _gutterWidth();
    // Density belongs between blocks, never inside their line boxes. Tight
    // items are solid; authored loose items spend the same half-beat interval
    // used by spaced prose.
    final between = list.loose ? theme.containerGap : 0.0;
    final children = <Widget>[];
    var itemOffset = offset;
    for (var i = 0; i < list.items.length; i++) {
      final direction = ReadingDirection.of(
        list.items[i].text,
        fallback: Directionality.of(context),
      );
      children.add(
        Directionality(
          textDirection: direction,
          child: Row(
            textDirection: direction,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: gutter,
                child: _Marker(list: list, index: i, theme: theme),
              ),
              Expanded(
                child: _BlockSequence(
                  blocks: list.items[i].blocks,
                  theme: theme,
                  composer: composer,
                  codeHighlighter: codeHighlighter,
                  mermaidRenderer: mermaidRenderer,
                  keys: keys,
                  customKeys: customKeys,
                  matchKeys: matchKeys,
                  startOffset: itemOffset,
                  separatorLength: 1,
                  spaceAfter: (current, next) => theme.spaceAfterInContainer(
                    current,
                    next,
                    tight: !list.loose,
                  ),
                  reconcileContainers: false,
                ),
              ),
            ],
          ),
        ),
      );
      if (i + 1 < list.items.length && between > 0) {
        children.add(SizedBox(height: between));
      }
      itemOffset += list.items[i].text.length + 1;
    }
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
    if (!reconcile) return content;
    return _RhythmicContainer(
      beat: theme.baseline,
      followingSpace: followingSpace,
      child: content,
    );
  }

  /// The marker column follows the widest marker the author actually needs.
  /// A fixed em gutter clips high starting numbers and makes wrapped text look
  /// as though it belongs to the marker rather than to the item.
  double _gutterWidth() {
    var markerWidth = list.items.any((item) => item.checked != null)
        ? theme.em
        : 0.0;
    for (var i = 0; i < list.items.length; i++) {
      if (list.items[i].checked != null) continue;
      markerWidth = math.max(
        markerWidth,
        ReadingMeasure.widthOf(
          _markerLabel(list, i),
          theme.marker,
          scaler: theme.textScaler,
        ),
      );
    }
    return markerWidth + theme.em * 0.5;
  }
}

class _Marker extends StatelessWidget {
  final ListBlock list;
  final int index;
  final ReadingTheme theme;

  const _Marker({required this.list, required this.index, required this.theme});

  @override
  Widget build(BuildContext context) {
    final item = list.items[index];
    if (item.checked != null) {
      return Padding(
        padding: EdgeInsetsDirectional.only(end: theme.em * 0.5),
        child: Semantics(
          checked: item.checked,
          label: item.checked! ? 'Completed task' : 'Incomplete task',
          child: ExcludeSemantics(
            child: SizedBox(
              height: theme.baseline,
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Icon(
                  item.checked!
                      ? Icons.check_box_outlined
                      : Icons.check_box_outline_blank,
                  size: theme.em,
                  color: item.checked!
                      ? theme.palette.accent
                      : theme.palette.muted,
                ),
              ),
            ),
          ),
        ),
      );
    }
    // Markers are signposts: they mark the line without competing with it.
    final label = _markerLabel(list, index);
    return Padding(
      padding: EdgeInsetsDirectional.only(end: theme.em * 0.5),
      child: Text(
        label,
        maxLines: 1,
        softWrap: false,
        textAlign: TextAlign.end,
        style: theme.marker,
      ),
    );
  }
}

String _markerLabel(ListBlock list, int index) =>
    list.ordered ? '${list.start + index}.' : '•';

/// Reconciles a recursive container after its children have established their
/// real height.
///
/// Half-beat relationships are useful inside a quote or loose list, but the
/// complete departure plus its forward-owned external space must still hand
/// the following prose back on the body grid. The correction belongs below
/// the container's content; putting it above would invent a second top-margin
/// convention.
final class _RhythmicContainer extends SingleChildRenderObjectWidget {
  final double beat;
  final double followingSpace;

  const _RhythmicContainer({
    required this.beat,
    required this.followingSpace,
    required super.child,
  });

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderRhythmicContainer(beat, followingSpace);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderRhythmicContainer renderObject,
  ) {
    renderObject
      ..beat = beat
      ..followingSpace = followingSpace;
  }
}

final class _RenderRhythmicContainer extends RenderShiftedBox {
  _RenderRhythmicContainer(this._beat, this._followingSpace, [RenderBox? child])
    : super(child);

  double _beat;
  double _followingSpace;

  set beat(double value) {
    if (_beat == value) return;
    _beat = value;
    markNeedsLayout();
  }

  set followingSpace(double value) {
    if (_followingSpace == value) return;
    _followingSpace = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }

    child.layout(constraints.loosen(), parentUsesSize: true);
    final complete = child.size.height + _followingSpace;
    final reconciled = _ceilToBeat(complete, _beat) - _followingSpace;
    size = constraints.constrain(Size(child.size.width, reconciled));
    final childParentData = child.parentData! as BoxParentData;
    childParentData.offset = Offset.zero;
  }
}

/// Rounds a completed surface up without charging a phantom beat for shaping
/// noise at an already-whole boundary.
double _ceilToBeat(double height, double beat) {
  final beats = height / beat;
  final nearest = beats.roundToDouble();
  final reconciled = (beats - nearest).abs() < 0.01
      ? nearest
      : beats.ceilToDouble();
  return reconciled * beat;
}

/// A table: aligned as the author asked, figures lining up in their columns,
/// and scrolling sideways rather than crushing its columns.
class _Table extends StatefulWidget {
  final TableBlock table;
  final ReadingTheme theme;
  final InlineComposer composer;
  final int offset;

  const _Table({
    required this.table,
    required this.theme,
    required this.composer,
    required this.offset,
  });

  @override
  State<_Table> createState() => _TableState();
}

class _TableState extends State<_Table> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cellPadding = EdgeInsets.symmetric(
      horizontal: widget.theme.tableCellHorizontalPadding,
      vertical: widget.theme.em * 0.45,
    );

    Widget cell(
      TableCell cell,
      TextStyle style,
      int offset, {
      bool header = false,
    }) {
      final direction = ReadingDirection.of(
        cell.text,
        fallback: Directionality.of(context),
      );
      final contents = Padding(
        padding: cellPadding,
        child: Text.rich(
          TextSpan(
            children: widget.composer.compose(
              cell.content,
              style: style,
              offset: offset,
            ),
          ),
          textDirection: direction,
          textAlign: switch (cell.alignment) {
            ColumnAlignment.left => TextAlign.left,
            ColumnAlignment.center => TextAlign.center,
            ColumnAlignment.right => TextAlign.right,
          },
        ),
      );
      // RenderTable supplies table, row, and ordinary-cell roles itself. The
      // first row is authorial structure, though, so name it explicitly rather
      // than leaving assistive technology to infer headers from paint alone.
      return header
          ? Semantics(role: SemanticsRole.columnHeader, child: contents)
          : contents;
    }

    final columns = widget.table.head.length;
    var rowOffset = widget.offset;
    List<Widget> padded(
      List<TableCell> cells,
      TextStyle style, {
      bool header = false,
    }) {
      var cellOffset = rowOffset;
      final views = <Widget>[];
      for (var i = 0; i < columns; i++) {
        final value = i < cells.length ? cells[i] : const TableCell([]);
        views.add(cell(value, style, cellOffset, header: header));
        if (i < cells.length) cellOffset += value.text.length + 1;
      }
      rowOffset += cells.map((cell) => cell.text).join('\t').length + 1;
      return views;
    }

    final head = padded(
      widget.table.head,
      widget.theme.tableHead,
      header: true,
    );
    final rows = [
      for (final row in widget.table.rows) padded(row, widget.theme.tableBody),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (columns == 0) return const SizedBox.shrink();

        final minimumWidths = [
          for (var column = 0; column < columns; column++)
            _minimumColumnWidth(column),
        ];
        final minimumTableWidth = minimumWidths.fold<double>(
          0,
          (a, b) => a + b,
        );
        final tableWidth = minimumTableWidth < constraints.maxWidth
            ? constraints.maxWidth
            : minimumTableWidth;
        final expansion = tableWidth / minimumTableWidth;
        final columnWidths = [
          for (final width in minimumWidths) width * expansion,
        ];

        return ClipRRect(
          borderRadius: BorderRadius.circular(LibraryChromeScale.controlRadius),
          child: Scrollbar(
            controller: _scroll,
            // A clipped column looks complete. The persistent thumb is the
            // sign that the table continues beyond the reading band.
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: tableWidth,
                child: Table(
                  border: TableBorder.all(color: widget.theme.palette.border),
                  columnWidths: {
                    for (var column = 0; column < columns; column++)
                      column: FixedColumnWidth(columnWidths[column]),
                  },
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: [
                    TableRow(
                      decoration: BoxDecoration(
                        color: widget.theme.palette.panel,
                      ),
                      children: head,
                    ),
                    for (final row in rows) TableRow(children: row),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  double _minimumColumnWidth(int column) {
    var width = widget.theme.minimumTableCellWidth(
      widget.table.head[column].text,
      widget.theme.tableHead,
    );
    for (final row in widget.table.rows) {
      if (column >= row.length) continue;
      final cellWidth = widget.theme.minimumTableCellWidth(
        row[column].text,
        widget.theme.tableBody,
      );
      if (cellWidth > width) width = cellWidth;
    }
    return width;
  }
}

/// One paragraph, set with its indent and with its opening mark hung.
class Paragraph extends StatelessWidget {
  final List<InlineSpan> spans;
  final TextStyle style;
  final TextScaler textScaler;

  /// Holds every line to the same height, so a code span or a smaller run
  /// inside the paragraph cannot push a line off the beat.
  final StrutStyle? strut;

  /// First-line indent. A hanging mark hangs from here, not from the column
  /// edge: the indent moves the line, and the mark hangs off the line.
  final double indent;

  const Paragraph({
    super.key,
    required this.spans,
    required this.style,
    this.textScaler = TextScaler.noScaling,
    this.strut,
    this.indent = 0,
  });

  @override
  Widget build(BuildContext context) {
    final (mark, rest) = splitHangingMark(spans);
    final set = bindWidow(rest);
    final paragraphStrut = set.any(_containsWidget) ? null : strut;
    final direction = ReadingDirection.of(
      set.map(_plainOf).join(),
      fallback: Directionality.of(context),
    );

    final flow = Text.rich(
      // The forced prose strut prevents a small code run from changing the
      // baseline. A widget placeholder is real content with its own height;
      // forcing the strut there would collapse the line box while the image
      // continued painting over the blocks below it.
      strutStyle: paragraphStrut,
      // Running prose follows the reading direction: flush at the edge where
      // the eye begins each line, ragged at the edge where it leaves. Unlike
      // justification, this never stretches word spaces into rivers.
      textAlign: TextAlign.start,
      textDirection: direction,
      softWrap: true,
      TextSpan(
        children: [
          if (indent > 0)
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: SizedBox(width: indent, height: 0),
            ),
          ...set,
        ],
      ),
    );
    if (mark == null) return flow;

    // The mark is taken out of the flow and painted beside it, so the text
    // begins on the column edge and the mark sits outside it. Same style and
    // same top, so the two share the first line's baseline exactly.
    final hang =
        ReadingMeasure.widthOf(mark, style, scaler: textScaler) *
        HangingPunctuation.fractionFor(mark);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        flow,
        Positioned(
          left: direction == TextDirection.ltr ? indent - hang : null,
          right: direction == TextDirection.rtl ? indent - hang : null,
          top: 0,
          child: Text(mark, style: style, textDirection: direction),
        ),
      ],
    );
  }

  /// Binds the last two words of the paragraph so the final one cannot be
  /// left standing on a line of its own.
  ///
  /// Only the last run is touched, and only when it ends in plain text: a
  /// paragraph ending in code or a link ends with something the reader can
  /// see is deliberate, and its spacing is not ours to change.
  static List<InlineSpan> bindWidow(List<InlineSpan> spans) {
    if (spans.isEmpty) return spans;
    final words = spans
        .map(_plainOf)
        .join()
        .trim()
        .split(RegExp(r'\s+'))
        .length;
    if (words < WidowBinding.leastWords) return spans;

    final last = spans.last;
    final bound = _bindLastLeaf(last);
    if (identical(bound, last)) return spans;
    return [...spans.take(spans.length - 1), bound];
  }

  static String _plainOf(InlineSpan span) =>
      span is TextSpan ? span.toPlainText() : ' ';

  static bool _containsWidget(InlineSpan span) =>
      span is WidgetSpan ||
      (span is TextSpan &&
          (span.children ?? const <InlineSpan>[]).any(_containsWidget));

  /// Binds the last eligible text leaf while preserving its surrounding mark.
  /// Links and code are deliberate endings: changing their text would change
  /// what gets followed or copied, so they remain untouched.
  static InlineSpan _bindLastLeaf(InlineSpan span) {
    if (span is! TextSpan ||
        span is InlineCodeSpan ||
        span.recognizer != null) {
      return span;
    }
    if (span.style?.backgroundColor != null) return span;

    final children = span.children;
    if (children != null && children.isNotEmpty) {
      final last = children.last;
      final bound = _bindLastLeaf(last);
      if (identical(bound, last)) return span;
      return TextSpan(
        text: span.text,
        children: [...children.take(children.length - 1), bound],
        style: span.style,
        recognizer: span.recognizer,
        mouseCursor: span.mouseCursor,
        onEnter: span.onEnter,
        onExit: span.onExit,
        semanticsLabel: span.semanticsLabel,
        locale: span.locale,
        spellOut: span.spellOut,
      );
    }

    final text = span.text;
    if (text == null || text.isEmpty) return span;
    final bound = WidowBinding.bindLastSpace(text);
    if (bound == text) return span;
    return TextSpan(
      text: bound,
      style: span.style,
      recognizer: span.recognizer,
      mouseCursor: span.mouseCursor,
      onEnter: span.onEnter,
      onExit: span.onExit,
      semanticsLabel: span.semanticsLabel,
      locale: span.locale,
      spellOut: span.spellOut,
    );
  }

  /// Splits an opening mark off the front of a paragraph, when it has one.
  ///
  /// Only a paragraph that *begins* with plain text can hang: a line opening
  /// with a link or with emphasis carries more than punctuation, and pulling
  /// that into the margin would move meaning rather than ink.
  static (String?, List<InlineSpan>) splitHangingMark(List<InlineSpan> spans) {
    if (spans.isEmpty) return (null, spans);
    final first = spans.first;
    if (first is! TextSpan) return (null, spans);
    final text = first.text;
    if (text == null || text.isEmpty) return (null, spans);
    final mark = text[0];
    if (!HangingPunctuation.hangs(mark)) return (null, spans);
    return (
      mark,
      [
        TextSpan(
          text: text.substring(1),
          style: first.style,
          children: first.children,
        ),
        ...spans.skip(1),
      ],
    );
  }
}
