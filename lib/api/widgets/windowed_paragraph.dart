import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:quiet_viewport/quiet_viewport.dart';

import '../../presentation/theme/widow_binding.dart';
import 'model_backed_selection_area.dart';

/// An upstream-proven suffix for one adjacent paragraph revision.
final class ParagraphSourceAppend {
  final int baseRevision;
  final String text;

  const ParagraphSourceAppend({required this.baseRevision, required this.text});
}

/// A large plain paragraph whose render cost is bounded by its viewport.
///
/// The complete source remains one semantic and selectable paragraph, while
/// only nearby visual lines become [RenderParagraph] objects. Line boundaries
/// are resolved by Flutter's own [TextPainter] and retained across upstream-
/// proven appends and final tail projections, so this does not substitute a
/// second typography engine.
final class WindowedPlainParagraph extends StatefulWidget {
  final String source;
  final int sourceRevision;
  final ParagraphSourceAppend? sourceAppend;
  final TextStyle style;
  final TextScaler textScaler;
  final StrutStyle? strutStyle;
  final TextDirection textDirection;
  final bool finalized;
  final Color? selectionColor;
  final Object selectionIdentity;
  final int selectionOrder;
  final ValueChanged<int>? debugOnSourceIndexed;

  const WindowedPlainParagraph({
    super.key,
    required this.source,
    required this.sourceRevision,
    this.sourceAppend,
    required this.style,
    this.textScaler = TextScaler.noScaling,
    this.strutStyle,
    required this.textDirection,
    required this.finalized,
    this.selectionColor,
    required this.selectionIdentity,
    required this.selectionOrder,
    this.debugOnSourceIndexed,
  });

  @override
  State<WindowedPlainParagraph> createState() => _WindowedPlainParagraphState();
}

final class _WindowedPlainParagraphState extends State<WindowedPlainParagraph> {
  static const _overscanLines = 8;

  ScrollPosition? _page;
  AppendWrapIndex? _lines;
  Object? _layoutSignature;
  var _indexedRevision = -1;
  var _indexedSourceLength = 0;
  var _firstLine = 0;
  var _lastLine = 1;
  var _lineHeight = 0.0;
  var _indexedFinalized = false;
  var _displaySource = '';

  double get _contentHeight => (_lines?.length ?? 1) * _lineHeight;

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
  void didUpdateWidget(WindowedPlainParagraph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source ||
        oldWidget.style != widget.style ||
        oldWidget.textScaler != widget.textScaler ||
        oldWidget.strutStyle != widget.strutStyle ||
        oldWidget.textDirection != widget.textDirection) {
      _scheduleSync();
    }
  }

  @override
  void dispose() {
    _page?.removeListener(_syncWindow);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      _ensureIndex(width);
      final lines = _lines!;
      final first = _firstLine.clamp(0, math.max(0, lines.length - 1)).toInt();
      final last = _lastLine.clamp(first + 1, lines.length).toInt();
      final start = lines.startAt(first);
      final end = last < lines.length
          ? lines.startAt(last)
          : _displaySource.length;
      final visible = _displaySource.substring(start, end);

      return Semantics(
        container: true,
        label: widget.source,
        textDirection: widget.textDirection,
        child: ExcludeSemantics(
          child: SizedBox(
            height: _contentHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  top: first * _lineHeight,
                  left: 0,
                  right: 0,
                  child: ModelSelectionBlock(
                    identity: widget.selectionIdentity,
                    order: widget.selectionOrder,
                    text: widget.source,
                    rangeOffset: start,
                    child: Text(
                      visible,
                      key: const ValueKey('paragraph-window'),
                      style: widget.style,
                      strutStyle: widget.strutStyle,
                      textScaler: widget.textScaler,
                      textAlign: TextAlign.start,
                      textDirection: widget.textDirection,
                      softWrap: true,
                      selectionColor: widget.selectionColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  void _ensureIndex(double width) {
    final signature = (
      width,
      widget.style,
      widget.textScaler,
      widget.strutStyle,
      widget.textDirection,
    );
    if (_lines == null || signature != _layoutSignature) {
      _layoutSignature = signature;
      _lineHeight = _measureLineHeight(width);
      _displaySource = _projectedSource();
      _lines = AppendWrapIndex(
        source: _displaySource,
        resolve: (text) => _resolveLineStarts(text, width),
      );
      _indexedRevision = widget.sourceRevision;
      _indexedSourceLength = widget.source.length;
      _indexedFinalized = widget.finalized;
      _firstLine = 0;
      _lastLine = math.min(1, _lines!.length);
      widget.debugOnSourceIndexed?.call(_lines!.lastIndexedCodeUnits);
      _scheduleSync();
      return;
    }
    if (_indexedRevision == widget.sourceRevision &&
        _indexedSourceLength == widget.source.length &&
        _indexedFinalized == widget.finalized) {
      return;
    }

    if (!_indexedFinalized &&
        widget.finalized &&
        _indexedSourceLength == widget.source.length) {
      final projected = _projectedSource();
      var indexedCodeUnits = 0;
      if (!identical(projected, widget.source)) {
        final changedAt = _changedOffset(_displaySource, projected);
        _displaySource = projected;
        _lines!.replaceTail(
          line: _lines!.lineAtOffset(changedAt),
          source: projected,
        );
        indexedCodeUnits = _lines!.lastIndexedCodeUnits;
      }
      _indexedRevision = widget.sourceRevision;
      _indexedFinalized = true;
      widget.debugOnSourceIndexed?.call(indexedCodeUnits);
      _scheduleSync();
      return;
    }

    final append = widget.sourceAppend;
    final directAppend =
        append != null &&
        append.baseRevision == _indexedRevision &&
        widget.sourceRevision > _indexedRevision &&
        _indexedSourceLength + append.text.length == widget.source.length;
    if (directAppend) {
      _displaySource = widget.source;
      _lines!.append(baseLength: _indexedSourceLength, source: _displaySource);
    } else {
      _displaySource = _projectedSource();
      _lines!.replace(_displaySource);
      _firstLine = 0;
      _lastLine = math.min(1, _lines!.length);
    }
    _indexedRevision = widget.sourceRevision;
    _indexedSourceLength = widget.source.length;
    _indexedFinalized = widget.finalized;
    widget.debugOnSourceIndexed?.call(_lines!.lastIndexedCodeUnits);
    _scheduleSync();
  }

  String _projectedSource() =>
      widget.finalized ? WidowBinding.bind(widget.source) : widget.source;

  static int _changedOffset(String before, String after) {
    final limit = math.min(before.length, after.length);
    for (var offset = limit - 1; offset >= 0; offset--) {
      if (before.codeUnitAt(offset) != after.codeUnitAt(offset)) return offset;
    }
    return limit;
  }

  List<int> _resolveLineStarts(String text, double width) {
    if (text.isEmpty) return const [0];
    final painter = TextPainter(
      text: TextSpan(text: text, style: widget.style),
      textAlign: TextAlign.start,
      textDirection: widget.textDirection,
      textScaler: widget.textScaler,
      strutStyle: widget.strutStyle,
      locale: widget.style.locale,
    )..layout(maxWidth: width);
    final starts = <int>[0];
    var offset = 0;
    while (offset < text.length) {
      final range = painter.getLineBoundary(TextPosition(offset: offset));
      var next = range.end;
      if (next < text.length && text.codeUnitAt(next) == 10) next++;
      if (next <= offset) {
        painter.dispose();
        throw StateError('Text layout did not advance from offset $offset.');
      }
      starts.add(next);
      offset = next;
    }
    if (starts.last == text.length && !text.endsWith('\n')) {
      starts.removeLast();
    }
    painter.dispose();
    return starts;
  }

  double _measureLineHeight(double width) {
    final painter = TextPainter(
      text: TextSpan(text: 'M', style: widget.style),
      textDirection: widget.textDirection,
      textScaler: widget.textScaler,
      strutStyle: widget.strutStyle,
      locale: widget.style.locale,
    )..layout(maxWidth: width);
    final height = painter.computeLineMetrics().single.height;
    painter.dispose();
    return height;
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
    final lines = _lines;
    if (page == null ||
        render == null ||
        viewport == null ||
        lines == null ||
        !render.attached ||
        _lineHeight <= 0) {
      return;
    }
    final blockStart = viewport
        .getOffsetToReveal(render, 0, axis: Axis.vertical)
        .offset;
    final local = (page.pixels - blockStart)
        .clamp(0.0, math.max(0.0, _contentHeight - page.viewportDimension))
        .toDouble();
    final first = math.max(0, (local / _lineHeight).floor() - _overscanLines);
    final last = math.min(
      lines.length,
      ((local + page.viewportDimension) / _lineHeight).ceil() + _overscanLines,
    );
    if (first == _firstLine && last == _lastLine) return;
    setState(() {
      _firstLine = first;
      _lastLine = last;
    });
  }
}
