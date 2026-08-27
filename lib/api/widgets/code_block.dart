import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../presentation/code/code_highlighter.dart';
import '../theme/library_chrome.dart';
import '../theme/library_theme.dart';

/// A fenced block with a quiet identity and two reading actions.
///
/// The source is always rendered first and remains the authority for selection
/// and copying. Highlighting may arrive later or not at all. Lines scroll by
/// default because wrapping changes how code appears to be structured; the
/// reader may opt into wrapping for one block when comprehension benefits.
final class ReadableCodeBlock extends StatefulWidget {
  final String source;
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
        !_wrap &&
        widget.source.length >= _virtualizationThreshold &&
        Scrollable.maybeOf(context, axis: Axis.vertical) != null;
    final body = virtualize
        ? _WindowedCodeSource(
            key: const ValueKey('code-source'),
            source: widget.source,
            highlighting: _highlighting,
            spansForRange: widget.spansForRange,
            textStyle: widget.textStyle.copyWith(
              backgroundColor: Colors.transparent,
            ),
            selectionColor: p.selection,
            padding: widget.padding,
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
  final CodeHighlighting? highlighting;
  final List<InlineSpan> Function(CodeHighlighting?, int, int) spansForRange;
  final TextStyle textStyle;
  final Color selectionColor;
  final EdgeInsets padding;

  const _WindowedCodeSource({
    super.key,
    required this.source,
    required this.highlighting,
    required this.spansForRange,
    required this.textStyle,
    required this.selectionColor,
    required this.padding,
  });

  @override
  State<_WindowedCodeSource> createState() => _WindowedCodeSourceState();
}

final class _WindowedCodeSourceState extends State<_WindowedCodeSource> {
  static const _overscanLines = 8;

  final _horizontal = ScrollController();
  ScrollPosition? _page;
  late _CodeLineIndex _lines = _CodeLineIndex(widget.source);
  var _firstLine = 0;
  var _lastLine = 1;

  double get _lineHeight =>
      (widget.textStyle.fontSize ?? 14) * (widget.textStyle.height ?? 1);

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
    if (oldWidget.source != widget.source) {
      _lines = _CodeLineIndex(widget.source);
      _firstLine = 0;
      _lastLine = math.min(1, _lines.length);
      _scheduleSync();
    }
  }

  void _scheduleSync() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncWindow();
    });
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
    final local = (page.pixels - blockStart).clamp(
      0.0,
      math.max(0.0, _contentHeight - page.viewportDimension),
    );
    final first = math.max(0, (local / _lineHeight).floor() - _overscanLines);
    final last = math.min(
      _lines.length,
      ((local + page.viewportDimension) / _lineHeight).ceil() + _overscanLines,
    );
    if (first == _firstLine && last == _lastLine) return;
    setState(() {
      _firstLine = first;
      _lastLine = last;
    });
  }

  double get _contentHeight =>
      widget.padding.vertical + _lines.length * _lineHeight;

  @override
  void dispose() {
    _page?.removeListener(_syncWindow);
    _horizontal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var line = _firstLine; line < _lastLine; line++) {
      final range = _lines.rangeAt(line);
      rows.add(
        SizedBox(
          key: ValueKey('code-line-$line'),
          height: _lineHeight,
          child: Text.rich(
            TextSpan(
              children: widget.spansForRange(
                widget.highlighting,
                range.start,
                range.end,
              ),
            ),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.clip,
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
    final characterWidth = _monospaceAdvance(widget.textStyle);
    final top = widget.padding.top + _firstLine * _lineHeight;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = math.max(
          0.0,
          constraints.maxWidth - widget.padding.horizontal,
        );
        final sourceWidth = math.max(
          availableWidth,
          _lines.maximumColumns * characterWidth,
        );
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
}

final class _CodeLineIndex {
  final List<int> _starts;
  final int _sourceLength;
  final int maximumColumns;

  factory _CodeLineIndex(String source) {
    final starts = <int>[0];
    var maximumColumns = 0;
    var currentColumns = 0;
    for (var index = 0; index < source.length; index++) {
      if (source.codeUnitAt(index) == 10) {
        maximumColumns = math.max(maximumColumns, currentColumns);
        currentColumns = 0;
        starts.add(index + 1);
      } else {
        currentColumns++;
      }
    }
    return _CodeLineIndex._(
      starts,
      source.length,
      math.max(maximumColumns, currentColumns),
    );
  }

  const _CodeLineIndex._(this._starts, this._sourceLength, this.maximumColumns);

  int get length => _starts.length;

  ({int start, int end}) rangeAt(int index) => (
    start: _starts[index],
    end: index + 1 < _starts.length ? _starts[index + 1] - 1 : _sourceLength,
  );
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
