import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:quiet_viewport/quiet_viewport.dart';

import '../../presentation/theme/widow_binding.dart';
import 'model_backed_selection_area.dart';

/// One bounded initial line-index operation observed by a profile harness.
typedef ParagraphIndexStepObserver = void Function(
  int codeUnits,
  Duration elapsed,
);

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
  final ParagraphIndexStepObserver? debugOnInitialIndexStep;

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
    this.debugOnInitialIndexStep,
  });

  @override
  State<WindowedPlainParagraph> createState() => _WindowedPlainParagraphState();
}

final class _WindowedPlainParagraphState extends State<WindowedPlainParagraph> {
  static const _overscanLines = 8;
  static const _maximumInitialWindowsPerFrame = 4;
  static const _initialIndexBudget = Duration(milliseconds: 4);

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
  var _modelSource = '';
  _PendingParagraphIndex? _pending;
  var _indexEpoch = 0;
  int? _scheduledIndexEpoch;

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
    _indexEpoch++;
    _page?.removeListener(_syncWindow);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      _ensureIndex(width);
      final lines = _lines!;
      if (!lines.isComplete) return _indexingPlaceholder();
      final first = _firstLine.clamp(0, math.max(0, lines.length - 1)).toInt();
      final last = _lastLine.clamp(first + 1, lines.length).toInt();
      final start = lines.startAt(first);
      final end = last < lines.length
          ? lines.startAt(last)
          : _displaySource.length;
      final visible = _displaySource.substring(start, end);

      return Semantics(
        container: true,
        label: _modelSource,
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
                    text: _modelSource,
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

  Widget _indexingPlaceholder() => Semantics(
    liveRegion: true,
    label: 'Preparing document text',
    child: SizedBox(
      key: const ValueKey('paragraph-indexing'),
      height: _lineHeight,
    ),
  );

  void _ensureIndex(double width) {
    final signature = _layoutSignatureFor(width);
    if (_lines == null || signature != _layoutSignature) {
      _beginInitialIndex(width, signature);
      return;
    }

    final pending = _pending;
    if (pending != null) {
      if (pending.revision == widget.sourceRevision &&
          pending.modelSource.length == widget.source.length &&
          pending.finalized == widget.finalized) {
        return;
      }
      final append = widget.sourceAppend;
      final directAppend =
          !widget.finalized &&
          append != null &&
          append.baseRevision == pending.revision &&
          widget.sourceRevision > pending.revision &&
          pending.modelSource.length + append.text.length ==
              widget.source.length;
      if (directAppend) {
        pending
          ..displaySource = widget.source
          ..modelSource = widget.source
          ..revision = widget.sourceRevision;
        pending.lines.stageAppend(
          baseLength: pending.lines.sourceLength,
          source: pending.displaySource,
        );
        pending.finalized = widget.finalized;
        _scheduleInitialIndex(pending.epoch, pending.lines);
      } else {
        _beginReplacementIndex(width);
      }
      return;
    }

    if (!_lines!.isComplete) {
      if (_indexedRevision == widget.sourceRevision &&
          _indexedSourceLength == widget.source.length &&
          _indexedFinalized == widget.finalized) {
        return;
      }
      final append = widget.sourceAppend;
      final directAppend =
          !widget.finalized &&
          append != null &&
          append.baseRevision == _indexedRevision &&
          widget.sourceRevision > _indexedRevision &&
          _indexedSourceLength + append.text.length == widget.source.length;
      if (directAppend) {
        _displaySource = widget.source;
        _lines!.stageAppend(
          baseLength: _indexedSourceLength,
          source: _displaySource,
        );
        _indexedRevision = widget.sourceRevision;
        _indexedSourceLength = widget.source.length;
        _modelSource = widget.source;
        _scheduleInitialIndex(_indexEpoch, _lines!);
      } else {
        _beginInitialIndex(width, signature);
      }
      _indexedFinalized = widget.finalized;
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
      _modelSource = widget.source;
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
      _modelSource = widget.source;
      _lines!.append(baseLength: _indexedSourceLength, source: _displaySource);
    } else {
      _beginReplacementIndex(width);
      return;
    }
    _indexedRevision = widget.sourceRevision;
    _indexedSourceLength = widget.source.length;
    _indexedFinalized = widget.finalized;
    widget.debugOnSourceIndexed?.call(_lines!.lastIndexedCodeUnits);
    _scheduleSync();
  }

  Object _layoutSignatureFor(double width) {
    final style = widget.style;
    final strut = widget.strutStyle;
    return (
      width: width,
      family: style.fontFamily,
      fallbacks: style.fontFamilyFallback?.join('\u0000'),
      size: style.fontSize,
      scaledSize: widget.textScaler.scale(style.fontSize ?? 14),
      weight: style.fontWeight?.value,
      fontStyle: style.fontStyle,
      letterSpacing: style.letterSpacing,
      wordSpacing: style.wordSpacing,
      height: style.height,
      leadingDistribution: style.leadingDistribution,
      locale: style.locale,
      features: style.fontFeatures?.join('\u0000'),
      variations: style.fontVariations?.join('\u0000'),
      direction: widget.textDirection,
      strutFamily: strut?.fontFamily,
      strutFallbacks: strut?.fontFamilyFallback?.join('\u0000'),
      strutSize: strut?.fontSize,
      strutHeight: strut?.height,
      strutLeading: strut?.leading,
      strutDistribution: strut?.leadingDistribution,
      strutWeight: strut?.fontWeight?.value,
      strutStyle: strut?.fontStyle,
      forceStrut: strut?.forceStrutHeight,
    );
  }

  void _beginInitialIndex(double width, Object signature) {
    final epoch = ++_indexEpoch;
    _layoutSignature = signature;
    _lineHeight = _measureLineHeight(width);
    _displaySource = _projectedSource();
    _modelSource = widget.source;
    _pending = null;
    _lines = AppendWrapIndex.progressive(
      source: _displaySource,
      resolve: (text) => _resolveLineStarts(text, width),
    );
    _indexedRevision = widget.sourceRevision;
    _indexedSourceLength = widget.source.length;
    _indexedFinalized = widget.finalized;
    _firstLine = 0;
    _lastLine = 1;
    _scheduleInitialIndex(epoch, _lines!);
  }

  void _beginReplacementIndex(double width) {
    final epoch = ++_indexEpoch;
    final displaySource = _projectedSource();
    final lines = AppendWrapIndex.progressive(
      source: displaySource,
      resolve: (text) => _resolveLineStarts(text, width),
    );
    _pending = _PendingParagraphIndex(
      lines: lines,
      displaySource: displaySource,
      modelSource: widget.source,
      revision: widget.sourceRevision,
      finalized: widget.finalized,
      epoch: epoch,
    );
    _scheduleInitialIndex(epoch, lines);
  }

  void _scheduleInitialIndex(
    int epoch,
    AppendWrapIndex lines, {
    bool afterFrame = true,
  }) {
    if (_scheduledIndexEpoch == epoch) return;
    _scheduledIndexEpoch = epoch;
    void run() {
      if (_scheduledIndexEpoch == epoch) _scheduledIndexEpoch = null;
      if (!mounted || epoch != _indexEpoch) return;

      final clock = Stopwatch()..start();
      var windows = 0;
      var complete = false;
      do {
        final stepClock = Stopwatch()..start();
        complete = lines.indexNext();
        stepClock.stop();
        windows++;
        widget.debugOnInitialIndexStep?.call(
          lines.lastIndexedCodeUnits,
          stepClock.elapsed,
        );
      } while (!complete &&
          windows < _maximumInitialWindowsPerFrame &&
          clock.elapsed < _initialIndexBudget);

      if (complete) {
        final pending = _pending;
        final indexedLength = pending != null && identical(pending.lines, lines)
            ? pending.modelSource.length
            : _modelSource.length;
        widget.debugOnSourceIndexed?.call(indexedLength);
        setState(() {
          if (pending != null && identical(pending.lines, lines)) {
            _lines = pending.lines;
            _displaySource = pending.displaySource;
            _modelSource = pending.modelSource;
            _indexedRevision = pending.revision;
            _indexedSourceLength = pending.modelSource.length;
            _indexedFinalized = pending.finalized;
            _pending = null;
          }
          _firstLine = 0;
          _lastLine = math.min(1, lines.length);
        });
        _scheduleSync();
      } else {
        _scheduleInitialIndex(epoch, lines, afterFrame: false);
      }
    }

    if (afterFrame) {
      WidgetsBinding.instance.addPostFrameCallback((_) => run());
      SchedulerBinding.instance.scheduleFrame();
    } else {
      Timer(const Duration(milliseconds: 1), run);
    }
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
        !lines.isComplete ||
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

final class _PendingParagraphIndex {
  final AppendWrapIndex lines;
  String displaySource;
  String modelSource;
  int revision;
  bool finalized;
  final int epoch;

  _PendingParagraphIndex({
    required this.lines,
    required this.displaySource,
    required this.modelSource,
    required this.revision,
    required this.finalized,
    required this.epoch,
  });
}
