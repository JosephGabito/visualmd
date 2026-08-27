import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:quiet_viewport/quiet_viewport.dart';

import '../../presentation/code/code_highlighter.dart';
import '../theme/library_chrome.dart';
import '../theme/library_theme.dart';

/// An upstream-proven suffix for one adjacent source revision.
final class CodeSourceAppend {
  final int baseRevision;
  final String text;

  const CodeSourceAppend({required this.baseRevision, required this.text});
}

/// A fenced block with a quiet identity and two reading actions.
///
/// The source is always rendered first and remains the authority for selection
/// and copying. Highlighting may arrive later or not at all. Lines scroll by
/// default because wrapping changes how code appears to be structured; the
/// reader may opt into wrapping for one block when comprehension benefits.
final class ReadableCodeBlock extends StatefulWidget {
  final String source;
  final int sourceRevision;
  final CodeSourceAppend? sourceAppend;
  final ValueChanged<int>? debugOnSourceIndexed;
  final String? language;
  final CodeHighlighter highlighter;
  final CodeHighlightScheme scheme;
  final List<InlineSpan> Function(CodeHighlighting? highlighting) spansFor;
  final List<InlineSpan> Function(
    CodeHighlighting? highlighting,
    int start,
    int end,
  )
  spansForRange;
  final TextStyle textStyle;
  final Color bodyBackground;
  final double beat;
  final double headerHeight;
  final EdgeInsets padding;
  final Decoration decoration;

  const ReadableCodeBlock({
    super.key,
    required this.source,
    this.sourceRevision = 0,
    this.sourceAppend,
    this.debugOnSourceIndexed,
    required this.language,
    required this.highlighter,
    required this.scheme,
    required this.spansFor,
    required this.spansForRange,
    required this.textStyle,
    required this.bodyBackground,
    required this.beat,
    required this.headerHeight,
    required this.padding,
    required this.decoration,
  });

  @override
  State<ReadableCodeBlock> createState() => _ReadableCodeBlockState();
}

final class _ReadableCodeBlockState extends State<ReadableCodeBlock> {
  static const _virtualizationThreshold = 32768;

  final _scroll = ScrollController();
  CodeHighlighting? _highlighting;
  Timer? _copyFeedback;
  var _request = 0;
  var _wrap = false;
  var _copied = false;

  @override
  void initState() {
    super.initState();
    _loadHighlighting();
  }

  @override
  void didUpdateWidget(ReadableCodeBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source ||
        oldWidget.language != widget.language ||
        oldWidget.scheme != widget.scheme ||
        !identical(oldWidget.highlighter, widget.highlighter)) {
      _highlighting = null;
      _loadHighlighting();
    }
  }

  Future<void> _loadHighlighting() async {
    final request = ++_request;
    if (widget.source.length >= _virtualizationThreshold) {
      // A large block classifies the mounted two-dimensional source window.
      // Sending its complete source to an enhancement would restore the very
      // length dependency that bounded layout removes.
      return;
    }
    CodeHighlighting? result;
    try {
      result = await widget.highlighter.highlight(
        source: widget.source,
        language: widget.language,
        scheme: widget.scheme,
      );
    } catch (_) {
      // A third-party contributor is held to the same fallback contract as
      // the bundled one: enhancement failure cannot hide the source.
      result = null;
    }
    if (!mounted || request != _request) return;
    setState(() => _highlighting = result);
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.source));
    if (!mounted) return;
    _copyFeedback?.cancel();
    setState(() => _copied = true);
    _copyFeedback = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  void dispose() {
    _request++;
    _copyFeedback?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final virtualize =
        widget.source.length >= _virtualizationThreshold &&
        Scrollable.maybeOf(context, axis: Axis.vertical) != null;
    final body = virtualize
        ? _WindowedCodeSource(
            key: const ValueKey('code-source'),
            source: widget.source,
            sourceRevision: widget.sourceRevision,
            sourceAppend: widget.sourceAppend,
            debugOnSourceIndexed: widget.debugOnSourceIndexed,
            highlighter: widget.highlighter,
            language: widget.language,
            scheme: widget.scheme,
            spansForRange: widget.spansForRange,
            textStyle: widget.textStyle.copyWith(
              backgroundColor: Colors.transparent,
            ),
            selectionColor: p.selection,
            padding: widget.padding,
            wrap: _wrap,
          )
        : _eagerBody(p.selection);

    return Container(
      key: const ValueKey('code-block-surface'),
      decoration: widget.decoration,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SelectionContainer.disabled(
            child: SizedBox(
              height: widget.headerHeight,
              child: Padding(
                padding: EdgeInsets.only(left: widget.padding.left),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.highlighter.labelFor(widget.language),
                        key: const ValueKey('code-language'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.chromeComponentLabel,
                      ),
                    ),
                    _CodeAction(
                      key: const ValueKey('code-wrap'),
                      label: _wrap ? 'Scroll long lines' : 'Wrap long lines',
                      toggled: _wrap,
                      icon: Icons.wrap_text_rounded,
                      extent: widget.headerHeight,
                      onPressed: () => setState(() => _wrap = !_wrap),
                    ),
                    _CodeAction(
                      key: const ValueKey('code-copy'),
                      label: _copied ? 'Code copied' : 'Copy code',
                      icon: _copied
                          ? Icons.check_rounded
                          : Icons.content_copy_rounded,
                      extent: widget.headerHeight,
                      onPressed: _copy,
                    ),
                  ],
                ),
              ),
            ),
          ),
          ColoredBox(
            key: const ValueKey('code-body-surface'),
            color: widget.bodyBackground,
            child: _RhythmicCodeBody(
              beat: widget.beat,
              headerHeight: widget.headerHeight,
              child: body,
            ),
          ),
        ],
      ),
    );
  }

  Widget _eagerBody(Color selectionColor) {
    final text = Text.rich(
      TextSpan(children: widget.spansFor(_highlighting)),
      key: const ValueKey('code-source'),
      style: widget.textStyle.copyWith(backgroundColor: Colors.transparent),
      softWrap: _wrap,
      selectionColor: selectionColor,
    );
    return _wrap
        ? Padding(padding: widget.padding, child: text)
        : ScrollbarTheme(
            data: ScrollbarTheme.of(context).copyWith(
              thickness: const WidgetStatePropertyAll(4),
              radius: const Radius.circular(LibraryChromeScale.componentRadius),
              thumbColor: WidgetStatePropertyAll(
                context.palette.muted.withValues(alpha: 0.55),
              ),
              trackVisibility: const WidgetStatePropertyAll(false),
            ),
            child: Scrollbar(
              controller: _scroll,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _scroll,
                scrollDirection: Axis.horizontal,
                padding: widget.padding,
                child: text,
              ),
            ),
          );
  }
}

/// Keeps one enormous fence in the outer reading flow while mounting only the
/// source lines near that flow's viewport.
///
/// A nested vertical scroller would change the reading physics and create a
/// second scrollbar. Instead this box reports the complete code height, moves
/// a small line window through that coordinate space, and follows the existing
/// page position. Horizontal scrolling remains local because it is an authored
/// property of code rather than document navigation.
final class _WindowedCodeSource extends StatefulWidget {
  final String source;
  final int sourceRevision;
  final CodeSourceAppend? sourceAppend;
  final ValueChanged<int>? debugOnSourceIndexed;
  final CodeHighlighter highlighter;
  final String? language;
  final CodeHighlightScheme scheme;
  final List<InlineSpan> Function(CodeHighlighting?, int, int) spansForRange;
  final TextStyle textStyle;
  final Color selectionColor;
  final EdgeInsets padding;
  final bool wrap;

  const _WindowedCodeSource({
    super.key,
    required this.source,
    required this.sourceRevision,
    required this.sourceAppend,
    required this.debugOnSourceIndexed,
    required this.highlighter,
    required this.language,
    required this.scheme,
    required this.spansForRange,
    required this.textStyle,
    required this.selectionColor,
    required this.padding,
    required this.wrap,
  });

  @override
  State<_WindowedCodeSource> createState() => _WindowedCodeSourceState();
}

final class _WindowedCodeSourceState extends State<_WindowedCodeSource> {
  static const _overscanLines = 8;
  static const _overscanColumns = 32;
  static const _highlightDebounce = Duration(milliseconds: 48);

  final _horizontal = ScrollController();
  ScrollPosition? _page;
  late AppendLineIndex _lines;
  var _firstLine = 0;
  var _lastLine = 1;
  var _firstColumn = 0;
  var _lastColumn = 512;
  Timer? _highlightTimer;
  CodeHighlighting? _windowHighlighting;
  var _highlightRequest = 0;
  IndexedExtentLedger? _wrappedGeometry;
  double? _wrappedWidth;
  var _wrappedLayoutRevision = 0;
  var _pendingWrappedCorrection = 0.0;
  var _wrappedCorrectionScheduled = false;

  double get _lineHeight =>
      (widget.textStyle.fontSize ?? 14) * (widget.textStyle.height ?? 1);

  double get _characterWidth => _monospaceAdvance(widget.textStyle);

  @override
  void initState() {
    super.initState();
    _lines = AppendLineIndex(widget.source);
    widget.debugOnSourceIndexed?.call(_lines.lastIndexedCodeUnits);
    _horizontal.addListener(_syncColumns);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = Scrollable.maybeOf(context, axis: Axis.vertical)?.position;
    if (identical(next, _page)) return;
    _page?.removeListener(_syncWindow);
    _page = next;
    _page?.addListener(_syncWindow);
    _scheduleSync();
  }

  @override
  void didUpdateWidget(_WindowedCodeSource oldWidget) {
    super.didUpdateWidget(oldWidget);
    final sourceChanged = oldWidget.source != widget.source;
    final append = widget.sourceAppend;
    final sourceAppended =
        sourceChanged &&
        append != null &&
        append.baseRevision == oldWidget.sourceRevision &&
        widget.sourceRevision > oldWidget.sourceRevision &&
        oldWidget.source.length + append.text.length == widget.source.length;
    if (sourceChanged) {
      if (sourceAppended) {
        final previousLineCount = _lines.length;
        _lines.append(append.text);
        widget.debugOnSourceIndexed?.call(_lines.lastIndexedCodeUnits);
        if (oldWidget.wrap == widget.wrap &&
            oldWidget.textStyle == widget.textStyle &&
            oldWidget.padding == widget.padding) {
          _extendWrappedGeometry(previousLineCount);
        } else {
          _wrappedGeometry = null;
          _wrappedWidth = null;
        }
      } else {
        _lines = AppendLineIndex(widget.source);
        widget.debugOnSourceIndexed?.call(_lines.lastIndexedCodeUnits);
        _firstLine = 0;
        _lastLine = math.min(1, _lines.length);
        _firstColumn = 0;
        _lastColumn = 512;
        _wrappedGeometry = null;
        _wrappedWidth = null;
      }
      _windowHighlighting = null;
    }
    final classificationChanged =
        sourceChanged ||
        oldWidget.language != widget.language ||
        oldWidget.scheme != widget.scheme ||
        !identical(oldWidget.highlighter, widget.highlighter);
    final geometryChanged =
        sourceChanged ||
        oldWidget.wrap != widget.wrap ||
        oldWidget.textStyle != widget.textStyle ||
        oldWidget.padding != widget.padding;
    if (oldWidget.wrap != widget.wrap) {
      _firstLine = 0;
      _lastLine = math.min(1, _lines.length);
      _firstColumn = 0;
      _lastColumn = 512;
      _windowHighlighting = null;
      _wrappedGeometry = null;
      _wrappedWidth = null;
    }
    if (geometryChanged) {
      _scheduleSync();
    } else if (classificationChanged) {
      _scheduleHighlighting();
    }
  }

  void _scheduleSync() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncWindow();
      _syncColumns();
      _scheduleHighlighting();
    });
  }

  void _syncColumns() {
    if (widget.wrap) return;
    if (!_horizontal.hasClients) return;
    final position = _horizontal.position;
    final first = math.max(
      0,
      (position.pixels / _characterWidth).floor() - _overscanColumns,
    );
    final last = math.min(
      _lines.maximumColumns,
      ((position.pixels + position.viewportDimension) / _characterWidth)
              .ceil() +
          _overscanColumns,
    );
    if (first == _firstColumn && last == _lastColumn) return;
    setState(() {
      _firstColumn = first;
      _lastColumn = last;
    });
    _scheduleHighlighting();
  }

  void _syncWindow() {
    final page = _page;
    final render = context.findRenderObject();
    final viewport = RenderAbstractViewport.maybeOf(render);
    if (page == null ||
        render == null ||
        viewport == null ||
        !render.attached) {
      return;
    }
    final blockStart = viewport
        .getOffsetToReveal(render, 0, axis: Axis.vertical)
        .offset;
    final local = (page.pixels - blockStart)
        .clamp(0.0, math.max(0.0, _contentHeight - page.viewportDimension))
        .toDouble();
    final (first, last) = widget.wrap
        ? _wrappedWindow(local, page.viewportDimension)
        : (
            math.max(0, (local / _lineHeight).floor() - _overscanLines),
            math.min(
              _lines.length,
              ((local + page.viewportDimension) / _lineHeight).ceil() +
                  _overscanLines,
            ),
          );
    if (first == _firstLine && last == _lastLine) return;
    setState(() {
      _firstLine = first;
      _lastLine = last;
    });
    _scheduleHighlighting();
  }

  (int, int) _wrappedWindow(double local, double viewport) {
    final geometry = _wrappedGeometry;
    if (geometry == null || geometry.length == 0) {
      return (0, math.min(1, _lines.length));
    }
    final contentStart = math.max(0.0, local - widget.padding.top);
    final contentEnd = math.max(0.0, local + viewport - widget.padding.top);
    final firstVisible = geometry.indexAtOffset(contentStart) ?? 0;
    final lastVisible = geometry.indexAtOffset(contentEnd) ?? firstVisible;
    return (
      math.max(0, firstVisible - _overscanLines),
      math.min(_lines.length, lastVisible + _overscanLines + 1),
    );
  }

  void _scheduleHighlighting() {
    final request = ++_highlightRequest;
    _highlightTimer?.cancel();
    _highlightTimer = Timer(_highlightDebounce, () {
      if (mounted && request == _highlightRequest) {
        _loadWindowHighlighting(request);
      }
    });
  }

  Future<void> _loadWindowHighlighting(int request) async {
    final window = _highlightWindow();
    if (window.text.isEmpty) {
      if (mounted && request == _highlightRequest) {
        setState(() => _windowHighlighting = null);
      }
      return;
    }
    CodeHighlighting? result;
    try {
      result = await widget.highlighter.highlight(
        source: window.text,
        language: widget.language,
        scheme: widget.scheme,
      );
    } catch (_) {
      result = null;
    }
    if (!mounted || request != _highlightRequest) return;
    setState(() {
      _windowHighlighting = result == null
          ? null
          : _mapWindowHighlighting(result, window.segments);
    });
  }

  _CodeHighlightWindow _highlightWindow() {
    final buffer = StringBuffer();
    final segments = <_CodeHighlightSegment>[];
    for (var line = _firstLine; line < _lastLine; line++) {
      final range = _lines.rangeAt(line);
      final columns = range.end - range.start;
      final firstColumn = widget.wrap ? 0 : math.min(_firstColumn, columns);
      final lastColumn = widget.wrap ? columns : math.min(_lastColumn, columns);
      final sourceStart = _safeSliceStart(
        widget.source,
        range.start + firstColumn,
        range.start,
      );
      final sourceEnd = _safeSliceEnd(
        widget.source,
        range.start + lastColumn,
        range.end,
      );
      if (sourceStart >= sourceEnd) continue;
      if (buffer.isNotEmpty) buffer.write('\n');
      final windowStart = buffer.length;
      buffer.write(widget.source.substring(sourceStart, sourceEnd));
      segments.add(
        _CodeHighlightSegment(
          sourceStart: sourceStart,
          sourceEnd: sourceEnd,
          windowStart: windowStart,
          windowEnd: buffer.length,
        ),
      );
    }
    return _CodeHighlightWindow(buffer.toString(), segments);
  }

  double get _contentHeight =>
      widget.padding.vertical +
      (widget.wrap
          ? (_wrappedGeometry?.totalExtent ?? _lines.length * _lineHeight)
          : _lines.length * _lineHeight);

  @override
  void dispose() {
    _page?.removeListener(_syncWindow);
    _horizontal.removeListener(_syncColumns);
    _highlightRequest++;
    _highlightTimer?.cancel();
    _horizontal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final characterWidth = _characterWidth;
    final top = widget.padding.top + _firstLine * _lineHeight;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = math.max(
          0.0,
          constraints.maxWidth - widget.padding.horizontal,
        );
        if (widget.wrap) return _buildWrapped(context, availableWidth);
        final sourceWidth = math.max(
          availableWidth,
          _lines.maximumColumns * characterWidth,
        );
        final rows = <Widget>[];
        for (var line = _firstLine; line < _lastLine; line++) {
          final range = _lines.rangeAt(line);
          final columns = range.end - range.start;
          final firstColumn = math.min(_firstColumn, columns);
          final lastColumn = math.min(_lastColumn, columns);
          final start = _safeSliceStart(
            widget.source,
            range.start + firstColumn,
            range.start,
          );
          final end = _safeSliceEnd(
            widget.source,
            range.start + lastColumn,
            range.end,
          );
          final text = start < end
              ? Text.rich(
                  TextSpan(
                    children: widget.spansForRange(
                      _windowHighlighting,
                      start,
                      end,
                    ),
                  ),
                  key: ValueKey('code-column-$start-$end'),
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.clip,
                  style: widget.textStyle,
                  strutStyle: StrutStyle.fromTextStyle(
                    widget.textStyle,
                    forceStrutHeight: true,
                  ),
                  selectionColor: widget.selectionColor,
                )
              : null;
          rows.add(
            SizedBox(
              key: ValueKey('code-line-$line'),
              width: sourceWidth,
              height: _lineHeight,
              child: text == null
                  ? null
                  : Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        Positioned(
                          left: (start - range.start) * characterWidth,
                          top: 0,
                          child: text,
                        ),
                      ],
                    ),
            ),
          );
        }
        return SizedBox(
          height: _contentHeight,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned(
                top: top,
                left: 0,
                right: 0,
                height: math.max(0, rows.length * _lineHeight),
                child: ScrollbarTheme(
                  data: ScrollbarTheme.of(context).copyWith(
                    thickness: const WidgetStatePropertyAll(4),
                    radius: const Radius.circular(
                      LibraryChromeScale.componentRadius,
                    ),
                    thumbColor: WidgetStatePropertyAll(
                      context.palette.muted.withValues(alpha: 0.55),
                    ),
                    trackVisibility: const WidgetStatePropertyAll(false),
                  ),
                  child: Scrollbar(
                    controller: _horizontal,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _horizontal,
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(
                        horizontal: widget.padding.left,
                      ),
                      child: SizedBox(
                        width: sourceWidth,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: rows,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWrapped(BuildContext context, double availableWidth) {
    if (availableWidth <= 0) return const SizedBox.shrink();
    _configureWrappedGeometry(availableWidth);
    final geometry = _wrappedGeometry!;
    final textScaler = MediaQuery.textScalerOf(context);
    final rows = <Widget>[];

    for (var line = _firstLine; line < _lastLine; line++) {
      final range = _lines.rangeAt(line);
      final children = range.start < range.end
          ? widget.spansForRange(_windowHighlighting, range.start, range.end)
          : const <InlineSpan>[];
      final span = TextSpan(style: widget.textStyle, children: children);
      final painter = TextPainter(
        text: span,
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
        strutStyle: StrutStyle.fromTextStyle(
          widget.textStyle,
          forceStrutHeight: true,
        ),
      )..layout(maxWidth: availableWidth);
      final measured = math.max(_lineHeight, painter.height);
      final correction = geometry.measure(
        index: line,
        layoutRevision: _wrappedLayoutRevision,
        extent: measured,
        anchor: _firstLine,
      );
      if (correction != null && correction.scrollOffsetDelta != 0) {
        _queueWrappedCorrection(correction.scrollOffsetDelta);
      }
      rows.add(
        Positioned(
          key: ValueKey('code-line-$line'),
          top: widget.padding.top + geometry.leadingOffsetAt(line),
          left: widget.padding.left,
          right: widget.padding.right,
          height: geometry.extentAt(line),
          child: range.start == range.end
              ? const SizedBox.shrink()
              : Text.rich(
                  TextSpan(children: children),
                  key: ValueKey('code-column-${range.start}-${range.end}'),
                  softWrap: true,
                  style: widget.textStyle,
                  strutStyle: StrutStyle.fromTextStyle(
                    widget.textStyle,
                    forceStrutHeight: true,
                  ),
                  selectionColor: widget.selectionColor,
                ),
        ),
      );
    }

    return SizedBox(
      height: widget.padding.vertical + geometry.totalExtent,
      child: Stack(clipBehavior: Clip.hardEdge, children: rows),
    );
  }

  void _configureWrappedGeometry(double width) {
    final previousWidth = _wrappedWidth;
    final characterWidth = _characterWidth;
    if (_wrappedGeometry == null) {
      final geometry = IndexedExtentLedger([
        for (var line = 0; line < _lines.length; line++)
          _estimatedWrappedExtent(line, width, characterWidth),
      ], layoutRevision: _wrappedLayoutRevision);
      _wrappedGeometry = geometry;
      _wrappedWidth = width;
      _scheduleSync();
      return;
    }
    if (previousWidth == width) return;
    _wrappedLayoutRevision++;
    _wrappedGeometry!.relayout(
      revision: _wrappedLayoutRevision,
      estimatedExtents: [
        for (var line = 0; line < _lines.length; line++)
          _estimatedWrappedExtent(line, width, characterWidth),
      ],
      anchor: _firstLine,
    );
    _wrappedWidth = width;
    _scheduleSync();
  }

  void _extendWrappedGeometry(int previousLineCount) {
    final geometry = _wrappedGeometry;
    final width = _wrappedWidth;
    if (geometry == null ||
        width == null ||
        geometry.length != previousLineCount) {
      _wrappedGeometry = null;
      _wrappedWidth = null;
      return;
    }
    final characterWidth = _characterWidth;
    geometry.revise(
      index: previousLineCount - 1,
      estimatedExtent: _estimatedWrappedExtent(
        previousLineCount - 1,
        width,
        characterWidth,
      ),
      anchor: _firstLine,
    );
    geometry.appendAll([
      for (var line = previousLineCount; line < _lines.length; line++)
        _estimatedWrappedExtent(line, width, characterWidth),
    ]);
  }

  double _estimatedWrappedExtent(
    int line,
    double width,
    double characterWidth,
  ) {
    final range = _lines.rangeAt(line);
    final columns = range.end - range.start;
    final rows = math.max(1, (columns * characterWidth / width).ceil());
    return rows * _lineHeight;
  }

  void _queueWrappedCorrection(double delta) {
    _pendingWrappedCorrection += delta;
    if (_wrappedCorrectionScheduled) return;
    _wrappedCorrectionScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _wrappedCorrectionScheduled = false;
      final correction = _pendingWrappedCorrection;
      _pendingWrappedCorrection = 0;
      final page = _page;
      if (!mounted || page == null || correction == 0) return;
      page.jumpTo(
        (page.pixels + correction).clamp(
          page.minScrollExtent,
          page.maxScrollExtent,
        ),
      );
      _syncWindow();
    });
  }
}

final class _CodeHighlightWindow {
  final String text;
  final List<_CodeHighlightSegment> segments;

  const _CodeHighlightWindow(this.text, this.segments);
}

final class _CodeHighlightSegment {
  final int sourceStart;
  final int sourceEnd;
  final int windowStart;
  final int windowEnd;

  const _CodeHighlightSegment({
    required this.sourceStart,
    required this.sourceEnd,
    required this.windowStart,
    required this.windowEnd,
  });
}

CodeHighlighting _mapWindowHighlighting(
  CodeHighlighting highlighting,
  List<_CodeHighlightSegment> segments,
) {
  final tokens = <CodeHighlightToken>[];
  for (final token in highlighting.tokens) {
    for (final segment in segments) {
      final start = math.max(token.start, segment.windowStart);
      final end = math.min(token.end, segment.windowEnd);
      if (start >= end) continue;
      final sourceStart = segment.sourceStart + start - segment.windowStart;
      final sourceEnd = segment.sourceStart + end - segment.windowStart;
      if (sourceStart < segment.sourceStart || sourceEnd > segment.sourceEnd) {
        continue;
      }
      tokens.add(
        CodeHighlightToken(
          start: sourceStart,
          end: sourceEnd,
          role: token.role,
          foreground: token.foreground,
        ),
      );
    }
  }
  tokens.sort((a, b) => a.start.compareTo(b.start));
  return CodeHighlighting(tokens);
}

int _safeSliceStart(String source, int value, int minimum) {
  if (value <= minimum || value >= source.length) return value;
  final unit = source.codeUnitAt(value);
  return unit >= 0xDC00 && unit <= 0xDFFF ? value - 1 : value;
}

int _safeSliceEnd(String source, int value, int maximum) {
  if (value <= 0 || value >= maximum) return value;
  final unit = source.codeUnitAt(value);
  return unit >= 0xDC00 && unit <= 0xDFFF ? value + 1 : value;
}

double _monospaceAdvance(TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: '0', style: style),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();
  return painter.width;
}

/// Lets source lines keep their compact leading, then returns the completed
/// surface to the running-text grid.
///
/// The small correction is shared above and below the body. Keeping it inside
/// the coloured surface prevents a variable external margin from appearing
/// between the code and the prose that follows.
final class _RhythmicCodeBody extends SingleChildRenderObjectWidget {
  final double beat;
  final double headerHeight;

  const _RhythmicCodeBody({
    required this.beat,
    required this.headerHeight,
    required super.child,
  });

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderRhythmicCodeBody(beat, headerHeight);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderRhythmicCodeBody renderObject,
  ) {
    renderObject
      ..beat = beat
      ..headerHeight = headerHeight;
  }
}

final class _RenderRhythmicCodeBody extends RenderShiftedBox {
  _RenderRhythmicCodeBody(this._beat, this._headerHeight, [RenderBox? child])
    : super(child);

  double _beat;
  double get beat => _beat;
  set beat(double value) {
    if (_beat == value) return;
    _beat = value;
    markNeedsLayout();
  }

  double _headerHeight;
  double get headerHeight => _headerHeight;
  set headerHeight(double value) {
    if (_headerHeight == value) return;
    _headerHeight = value;
    markNeedsLayout();
  }

  BoxConstraints _childConstraints(BoxConstraints constraints) =>
      constraints.copyWith(minHeight: 0, maxHeight: double.infinity);

  double _reconciledHeight(double childHeight) =>
      ((headerHeight + childHeight) / beat).ceil() * beat - headerHeight;

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
    childParentData.offset = Offset(0, (size.height - child.size.height) / 2);
  }
}

final class _CodeAction extends StatelessWidget {
  final String label;
  final bool? toggled;
  final IconData icon;
  final double extent;
  final VoidCallback onPressed;

  const _CodeAction({
    super.key,
    required this.label,
    this.toggled,
    required this.icon,
    required this.extent,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        toggled: toggled,
        excludeSemantics: true,
        child: IconButton(
          onPressed: onPressed,
          constraints: BoxConstraints.tightFor(width: extent, height: extent),
          padding: EdgeInsets.zero,
          hoverColor: context.chrome.hover,
          focusColor: context.chrome.hover,
          highlightColor: Colors.transparent,
          icon: Icon(
            icon,
            size: 17,
            color: toggled == true ? p.accent : p.muted,
          ),
        ),
      ),
    );
  }
}
