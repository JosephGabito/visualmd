import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:quiet_viewport/quiet_viewport.dart';

import '../../presentation/theme/typographic_punctuation.dart';
import '../../presentation/theme/widow_binding.dart';
import 'model_backed_selection_area.dart';

/// One bounded initial paragraph-index operation observed by a profile harness.
typedef ParagraphIndexStepObserver = void Function(int units, Duration elapsed);

/// One displayed source range with exact authored-boundary recovery.
abstract interface class WindowedParagraphProjection {
  InlineSpan get span;
  String get text;
  int sourceOffsetAt(int displayOffset);
  String? previousDisplayAt(int displayOffset);
}

/// Composes one bounded source range without visiting its prefix.
typedef WindowedParagraphProjector = WindowedParagraphProjection Function({
  required int start,
  required int end,
  required String? previous,
  required int? widowOffset,
});

/// Locates the one source boundary finalization may make non-breaking.
typedef ParagraphWidowOffset = int? Function(String source);

/// An upstream-proven suffix for one adjacent paragraph revision.
final class ParagraphSourceAppend {
  final int baseRevision;
  final String text;

  const ParagraphSourceAppend({required this.baseRevision, required this.text});
}

/// An upstream-proven replacement after one retained source boundary.
final class ParagraphSourceTailReplace {
  final int baseRevision;
  final int prefixLength;
  final String text;

  const ParagraphSourceTailReplace({
    required this.baseRevision,
    required this.prefixLength,
    required this.text,
  }) : assert(prefixLength >= 0);
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
  final ParagraphSourceTailReplace? sourceTailReplace;
  final TextStyle style;
  final TextScaler textScaler;
  final StrutStyle? strutStyle;
  final TextDirection textDirection;
  final bool finalized;
  final Color? selectionColor;
  final WindowedParagraphProjector? rangeProjector;
  final ParagraphWidowOffset widowOffsetFor;
  final Object selectionIdentity;
  final int selectionOrder;

  /// Complete visual lines retained beyond each edge of the viewport.
  ///
  /// Plain text can keep a generous inexpensive margin. Dense styled text may
  /// choose zero because floor/ceil still mount every line paint can expose.
  final int overscanLines;
  final ValueChanged<int>? debugOnSourceIndexed;
  final ParagraphIndexStepObserver? debugOnInitialIndexStep;

  const WindowedPlainParagraph({
    super.key,
    required this.source,
    required this.sourceRevision,
    this.sourceAppend,
    this.sourceTailReplace,
    required this.style,
    this.textScaler = TextScaler.noScaling,
    this.strutStyle,
    required this.textDirection,
    required this.finalized,
    this.selectionColor,
    this.rangeProjector,
    this.widowOffsetFor = WidowBinding.bindingOffset,
    required this.selectionIdentity,
    required this.selectionOrder,
    this.overscanLines = 8,
    this.debugOnSourceIndexed,
    this.debugOnInitialIndexStep,
  }) : assert(overscanLines >= 0);

  @override
  State<WindowedPlainParagraph> createState() => _WindowedPlainParagraphState();
}

final class _WindowedPlainParagraphState extends State<WindowedPlainParagraph> {
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
  var _modelSource = '';
  _ParagraphProjection? _projection;
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
          : _modelSource.length;
      final visible = _projectRange(
        source: _modelSource.substring(start, end),
        sourceOffset: start,
        projection: _projection!,
      );

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
                    sourceOffsetAt: (displayOffset) =>
                        start + visible.sourceOffsetAt(displayOffset),
                    child: Text.rich(
                      visible.span,
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
          ..modelSource = widget.source
          ..revision = widget.sourceRevision;
        pending.projection.update(
          widget.source,
          finalized: widget.finalized,
          widowOffsetFor: widget.widowOffsetFor,
          rangeProjector: widget.rangeProjector,
        );
        pending.lines.stageAppend(
          baseLength: pending.lines.sourceLength,
          source: pending.modelSource,
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
        _projection!.update(
          widget.source,
          finalized: widget.finalized,
          widowOffsetFor: widget.widowOffsetFor,
          rangeProjector: widget.rangeProjector,
        );
        _lines!.stageAppend(
          baseLength: _indexedSourceLength,
          source: widget.source,
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
      _projection!.update(
        widget.source,
        finalized: true,
        widowOffsetFor: widget.widowOffsetFor,
        rangeProjector: widget.rangeProjector,
      );
      var indexedCodeUnits = 0;
      final widowOffset = _projection!.widowOffset;
      if (widowOffset != null) {
        _lines!.replaceTail(
          line: _lines!.lineAtOffset(widowOffset),
          source: widget.source,
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

    final tail = widget.sourceTailReplace;
    final directTailReplace =
        !widget.finalized &&
        tail != null &&
        tail.baseRevision == _indexedRevision &&
        widget.sourceRevision > _indexedRevision &&
        tail.prefixLength <= _indexedSourceLength &&
        tail.prefixLength + tail.text.length == widget.source.length;
    if (directTailReplace) {
      _modelSource = widget.source;
      _projection!.update(
        widget.source,
        finalized: false,
        widowOffsetFor: widget.widowOffsetFor,
        rangeProjector: widget.rangeProjector,
      );
      _lines!.replaceTail(
        line: _lines!.lineAtOffset(tail.prefixLength),
        source: widget.source,
      );
      _indexedRevision = widget.sourceRevision;
      _indexedSourceLength = widget.source.length;
      _indexedFinalized = false;
      widget.debugOnSourceIndexed?.call(_lines!.lastIndexedCodeUnits);
      _scheduleSync();
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
      _modelSource = widget.source;
      _projection!.update(
        widget.source,
        finalized: false,
        widowOffsetFor: widget.widowOffsetFor,
        rangeProjector: widget.rangeProjector,
      );
      _lines!.append(baseLength: _indexedSourceLength, source: widget.source);
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
    _modelSource = widget.source;
    _projection = _ParagraphProjection(
      widget.source,
      finalized: widget.finalized,
      widowOffsetFor: widget.widowOffsetFor,
      rangeProjector: widget.rangeProjector,
    );
    _pending = null;
    _lines = AppendWrapIndex.progressiveWithContext(
      source: _modelSource,
      resolveAt: (text, sourceOffset) => _resolveLineStarts(
        text,
        sourceOffset: sourceOffset,
        width: width,
        projection: _projection!,
      ),
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
    final projection = _ParagraphProjection(
      widget.source,
      finalized: widget.finalized,
      widowOffsetFor: widget.widowOffsetFor,
      rangeProjector: widget.rangeProjector,
    );
    final lines = AppendWrapIndex.progressiveWithContext(
      source: widget.source,
      resolveAt: (text, sourceOffset) => _resolveLineStarts(
        text,
        sourceOffset: sourceOffset,
        width: width,
        projection: projection,
      ),
    );
    _pending = _PendingParagraphIndex(
      lines: lines,
      projection: projection,
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
            _modelSource = pending.modelSource;
            _projection = pending.projection;
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

  List<int> _resolveLineStarts(
    String text, {
    required int sourceOffset,
    required double width,
    required _ParagraphProjection projection,
  }) {
    if (text.isEmpty) return const [0];
    final projected = _projectRange(
      source: text,
      sourceOffset: sourceOffset,
      projection: projection,
    );
    final painter = TextPainter(
      text: TextSpan(style: widget.style, children: [projected.span]),
      textAlign: TextAlign.start,
      textDirection: widget.textDirection,
      textScaler: widget.textScaler,
      strutStyle: widget.strutStyle,
      locale: widget.style.locale,
    )..layout(maxWidth: width);
    final starts = <int>[0];
    var offset = 0;
    while (offset < projected.text.length) {
      final range = painter.getLineBoundary(TextPosition(offset: offset));
      var next = range.end;
      if (next < projected.text.length &&
          projected.text.codeUnitAt(next) == 10) {
        next++;
      }
      if (next <= offset) {
        painter.dispose();
        throw StateError('Text layout did not advance from offset $offset.');
      }
      final sourceStart = projected.sourceOffsetAt(next);
      if (sourceStart > starts.last) {
        starts.add(sourceStart);
        projection.previousBySourceOffset[sourceOffset + sourceStart] =
            projected.previousDisplayAt(next);
      }
      offset = next;
    }
    if (starts.last == text.length && !text.endsWith('\n')) {
      starts.removeLast();
    }
    painter.dispose();
    return starts;
  }

  WindowedParagraphProjection _projectRange({
    required String source,
    required int sourceOffset,
    required _ParagraphProjection projection,
  }) {
    if (!projection.previousBySourceOffset.containsKey(sourceOffset)) {
      throw StateError(
        'No typographic context exists at source offset $sourceOffset.',
      );
    }
    final widowOffset = projection.widowOffset;
    final rangeProjector = projection.rangeProjector;
    if (rangeProjector != null) {
      return rangeProjector(
        start: sourceOffset,
        end: sourceOffset + source.length,
        previous: projection.previousBySourceOffset[sourceOffset],
        widowOffset: widowOffset,
      );
    }
    var displaySource = source;
    if (widowOffset != null &&
        widowOffset >= sourceOffset &&
        widowOffset < sourceOffset + source.length) {
      final local = widowOffset - sourceOffset;
      displaySource =
          '${source.substring(0, local)}${WidowBinding.nonBreakingSpace}'
          '${source.substring(local + 1)}';
    }
    return _PlainParagraphProjection(
      TypographicProjection.of(
        displaySource,
        previous: projection.previousBySourceOffset[sourceOffset],
      ),
    );
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
    final first = math.max(
      0,
      (local / _lineHeight).floor() - widget.overscanLines,
    );
    final last = math.min(
      lines.length,
      ((local + page.viewportDimension) / _lineHeight).ceil() +
          widget.overscanLines,
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
  final _ParagraphProjection projection;
  String modelSource;
  int revision;
  bool finalized;
  final int epoch;

  _PendingParagraphIndex({
    required this.lines,
    required this.projection,
    required this.modelSource,
    required this.revision,
    required this.finalized,
    required this.epoch,
  });
}

final class _ParagraphProjection {
  String source;
  bool finalized;
  int? widowOffset;
  ParagraphWidowOffset widowOffsetFor;
  WindowedParagraphProjector? rangeProjector;
  final Map<int, String?> previousBySourceOffset = {0: null};

  _ParagraphProjection(
    this.source, {
    required this.finalized,
    required this.widowOffsetFor,
    required this.rangeProjector,
  }) : widowOffset = finalized ? widowOffsetFor(source) : null;

  void update(
    String next, {
    required bool finalized,
    required ParagraphWidowOffset widowOffsetFor,
    required WindowedParagraphProjector? rangeProjector,
  }) {
    source = next;
    this.finalized = finalized;
    this.widowOffsetFor = widowOffsetFor;
    this.rangeProjector = rangeProjector;
    widowOffset = finalized ? widowOffsetFor(next) : null;
  }
}

final class _PlainParagraphProjection implements WindowedParagraphProjection {
  final TypographicProjection projection;

  const _PlainParagraphProjection(this.projection);

  @override
  InlineSpan get span => TextSpan(text: projection.text);

  @override
  String get text => projection.text;

  @override
  int sourceOffsetAt(int displayOffset) =>
      projection.sourceOffsetAt(displayOffset);

  @override
  String? previousDisplayAt(int displayOffset) =>
      projection.previousDisplayAt(displayOffset);
}
