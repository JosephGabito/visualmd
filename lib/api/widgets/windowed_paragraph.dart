import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:quiet_viewport/quiet_viewport.dart';

import 'model_backed_selection_area.dart';

/// An upstream-proven suffix for one adjacent paragraph revision.
final class ParagraphSourceAppend {
  final int baseRevision;
  final String text;

  const ParagraphSourceAppend({required this.baseRevision, required this.text});
}

/// A provisional plain paragraph whose render cost is bounded by its viewport.
///
/// The complete source remains one semantic and selectable paragraph, while
/// only nearby visual lines become [RenderParagraph] objects. Line boundaries
/// are resolved by Flutter's own [TextPainter] and retained across upstream-
/// proven appends, so this does not substitute a second typography engine.
final class WindowedProvisionalParagraph extends StatefulWidget {
  final String source;
  final int sourceRevision;
  final ParagraphSourceAppend? sourceAppend;
  final TextStyle style;
  final TextScaler textScaler;
  final StrutStyle? strutStyle;
  final TextDirection textDirection;
  final Color? selectionColor;
  final Object selectionIdentity;
  final int selectionOrder;
  final ValueChanged<int>? debugOnSourceIndexed;

  const WindowedProvisionalParagraph({
    super.key,
    required this.source,
    required this.sourceRevision,
    this.sourceAppend,
    required this.style,
    this.textScaler = TextScaler.noScaling,
    this.strutStyle,
    required this.textDirection,
    this.selectionColor,
    required this.selectionIdentity,
    required this.selectionOrder,
    this.debugOnSourceIndexed,
  });

  @override
  State<WindowedProvisionalParagraph> createState() =>
      _WindowedProvisionalParagraphState();
}

final class _WindowedProvisionalParagraphState
    extends State<WindowedProvisionalParagraph> {
  static const _overscanLines = 8;

  ScrollPosition? _page;
  AppendWrapIndex? _lines;
  Object? _layoutSignature;
  var _indexedRevision = -1;
  var _indexedSourceLength = 0;
  var _firstLine = 0;
  var _lastLine = 1;
  var _lineHeight = 0.0;

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
  void didUpdateWidget(WindowedProvisionalParagraph oldWidget) {
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
          : widget.source.length;
      final visible = widget.source.substring(start, end);

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
      _lines = AppendWrapIndex(
        source: widget.source,
        resolve: (text) => _resolveLineStarts(text, width),
      );
      _indexedRevision = widget.sourceRevision;
      _indexedSourceLength = widget.source.length;
      _firstLine = 0;
      _lastLine = math.min(1, _lines!.length);
      widget.debugOnSourceIndexed?.call(_lines!.lastIndexedCodeUnits);
      _scheduleSync();
      return;
    }
    if (_indexedRevision == widget.sourceRevision &&
        _indexedSourceLength == widget.source.length) {
      return;
    }

    final append = widget.sourceAppend;
    final directAppend =
        append != null &&
        append.baseRevision == _indexedRevision &&
        widget.sourceRevision > _indexedRevision &&
        _indexedSourceLength + append.text.length == widget.source.length;
    if (directAppend) {
      _lines!.append(baseLength: _indexedSourceLength, source: widget.source);
    } else {
      _lines!.replace(widget.source);
      _firstLine = 0;
      _lastLine = math.min(1, _lines!.length);
    }
    _indexedRevision = widget.sourceRevision;
    _indexedSourceLength = widget.source.length;
    widget.debugOnSourceIndexed?.call(_lines!.lastIndexedCodeUnits);
    _scheduleSync();
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
