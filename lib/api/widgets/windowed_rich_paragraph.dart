import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/reading/content/document_content.dart';
import '../../domain/reading/content/inline.dart';
import '../../presentation/theme/typographic_punctuation.dart';
import '../render/inline_composer.dart';
import '../render/inline_range_index.dart';
import '../render/reading_direction.dart';
import 'windowed_paragraph.dart';

/// A viewport-bounded paragraph whose inline meaning is also range-bounded.
///
/// The immutable [InlineRangeIndex] converts source offsets back into only the
/// intersecting emphasis, code and link structure. [WindowedPlainParagraph]
/// continues to own wrap persistence, scheduling, geometry and selection.
final class WindowedRichParagraph extends StatefulWidget {
  final List<Inline> content;
  final int sourceRevision;
  final BlockInlineAppend? inlineAppend;
  final BlockInlineTailReplace? inlineTailReplace;
  final InlineComposer composer;
  final int documentOffset;
  final TextStyle style;
  final TextScaler textScaler;
  final StrutStyle? strutStyle;
  final bool finalized;
  final Color? selectionColor;
  final Object selectionIdentity;
  final int selectionOrder;
  final ValueChanged<int>? debugOnSourceIndexed;
  final ParagraphIndexStepObserver? debugOnInitialIndexStep;

  const WindowedRichParagraph({
    super.key,
    required this.content,
    required this.sourceRevision,
    this.inlineAppend,
    this.inlineTailReplace,
    required this.composer,
    required this.documentOffset,
    required this.style,
    this.textScaler = TextScaler.noScaling,
    this.strutStyle,
    required this.finalized,
    this.selectionColor,
    required this.selectionIdentity,
    required this.selectionOrder,
    this.debugOnSourceIndexed,
    this.debugOnInitialIndexStep,
  });

  @override
  State<WindowedRichParagraph> createState() => _WindowedRichParagraphState();
}

final class _WindowedRichParagraphState extends State<WindowedRichParagraph> {
  static const _maximumBatchesPerTurn = 4;
  static const _buildBudget = Duration(milliseconds: 4);

  // Styled windows allocate span and recognizer state per authored run. The
  // scroll listener updates before paint and floor/ceil retain every visible
  // line, so rich text needs no speculative lines beyond the viewport. Plain
  // paragraphs keep their wider, inexpensive margin.
  static const _richOverscanLines = 0;

  InlineRangeIndex? _index;
  ProgressiveInlineRangeIndex? _pending;
  var _indexRevision = -1;
  var _indexFinalized = false;
  ParagraphSourceAppend? _sourceAppend;
  ParagraphSourceTailReplace? _sourceTailReplace;
  var _epoch = 0;
  int? _scheduledEpoch;

  @override
  void initState() {
    super.initState();
    _beginIndex();
  }

  @override
  void didUpdateWidget(WindowedRichParagraph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sourceRevision != widget.sourceRevision ||
        !identical(oldWidget.content, widget.content)) {
      if (_applyInlineAppend()) return;
      if (_applyInlineTailReplace()) return;
      _beginIndex();
    }
  }

  @override
  void dispose() {
    _epoch++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final index = _index;
    if (index == null) {
      final nominalSize = widget.style.fontSize ?? 14;
      final lineHeight =
          widget.textScaler.scale(nominalSize) * (widget.style.height ?? 1);
      return Semantics(
        key: const ValueKey('rich-paragraph-indexing'),
        label: 'Preparing styled document text',
        child: SizedBox(height: lineHeight),
      );
    }

    // A replacement keeps the last complete source and geometry visible. The
    // new revision enters the paragraph scheduler only after its range index
    // can be published as one immutable value.
    final replacing = _pending != null;
    return WindowedPlainParagraph(
      source: index.source,
      sourceRevision: replacing ? _indexRevision : widget.sourceRevision,
      sourceAppend: replacing ? null : _sourceAppend,
      sourceTailReplace: replacing ? null : _sourceTailReplace,
      style: widget.style,
      textScaler: widget.textScaler,
      strutStyle: widget.strutStyle,
      textDirection: ReadingDirection.of(
        index.source,
        fallback: Directionality.of(context),
      ),
      finalized: replacing ? _indexFinalized : widget.finalized,
      selectionColor: widget.selectionColor,
      rangeProjector:
          ({
            required start,
            required end,
            required previous,
            required widowOffset,
          }) => _projectRange(
            index: index,
            start: start,
            end: end,
            previous: previous,
            widowOffset: widowOffset,
          ),
      widowOffsetFor: (_) => index.widowOffset,
      selectionIdentity: widget.selectionIdentity,
      selectionOrder: widget.selectionOrder,
      overscanLines: _richOverscanLines,
      debugOnSourceIndexed: widget.debugOnSourceIndexed,
      debugOnInitialIndexStep: widget.debugOnInitialIndexStep,
    );
  }

  void _beginIndex() {
    final epoch = ++_epoch;
    _sourceAppend = null;
    _sourceTailReplace = null;
    _pending = ProgressiveInlineRangeIndex.fromSupported(widget.content);
    _scheduleIndex(epoch);
  }

  bool _applyInlineAppend() {
    final proof = widget.inlineAppend;
    final index = _index;
    if (_pending != null ||
        proof == null ||
        index == null ||
        _indexFinalized ||
        widget.finalized ||
        proof.baseRevision != _indexRevision ||
        widget.sourceRevision <= _indexRevision ||
        !InlineRangeIndex.supports(proof.runs)) {
      return false;
    }

    final appended = index.append(proof.runs);
    _index = appended;
    _indexRevision = widget.sourceRevision;
    _indexFinalized = false;
    _sourceAppend = ParagraphSourceAppend(
      baseRevision: proof.baseRevision,
      text: proof.runs.map((run) => run.text).join(),
    );
    _sourceTailReplace = null;
    return true;
  }

  bool _applyInlineTailReplace() {
    final proof = widget.inlineTailReplace;
    final index = _index;
    if (_pending != null ||
        proof == null ||
        index == null ||
        _indexFinalized ||
        widget.finalized ||
        proof.baseRevision != _indexRevision ||
        widget.sourceRevision <= _indexRevision ||
        proof.retainedPrefix.codeUnits > index.length ||
        !InlineRangeIndex.supports(proof.runs)) {
      return false;
    }

    final replaced = index.replaceTail(
      prefixLength: proof.retainedPrefix.codeUnits,
      runs: proof.runs,
    );
    _index = replaced;
    _indexRevision = widget.sourceRevision;
    _indexFinalized = false;
    _sourceAppend = null;
    _sourceTailReplace = ParagraphSourceTailReplace(
      baseRevision: proof.baseRevision,
      prefixLength: proof.retainedPrefix.codeUnits,
      text: proof.runs.map((run) => run.text).join(),
    );
    return true;
  }

  void _scheduleIndex(int epoch) {
    if (_scheduledEpoch == epoch) return;
    _scheduledEpoch = epoch;
    Timer(const Duration(milliseconds: 1), () {
      if (!mounted || epoch != _epoch) return;
      _scheduledEpoch = null;
      final pending = _pending;
      if (pending == null) return;

      final stopwatch = Stopwatch()..start();
      var batches = 0;
      while (!pending.isComplete &&
          batches < _maximumBatchesPerTurn &&
          stopwatch.elapsed < _buildBudget) {
        final stepClock = Stopwatch()..start();
        pending.indexNext();
        stepClock.stop();
        widget.debugOnInitialIndexStep?.call(
          pending.lastIndexedNodes,
          stepClock.elapsed,
        );
        batches++;
      }

      if (!mounted || epoch != _epoch || !identical(pending, _pending)) {
        return;
      }
      if (pending.isComplete) {
        setState(() {
          _index = pending.result;
          _indexRevision = widget.sourceRevision;
          _indexFinalized = widget.finalized;
          _sourceAppend = null;
          _sourceTailReplace = null;
          _pending = null;
        });
      } else {
        _scheduleIndex(epoch);
      }
    });
  }

  WindowedParagraphProjection _projectRange({
    required InlineRangeIndex index,
    required int start,
    required int end,
    required String? previous,
    required int? widowOffset,
  }) {
    final cursor = _RichProjectionCursor(previous);
    final projected = [
      for (final run in index.slice(start, end))
        _projectRun(
          run,
          rangeStart: start,
          widowOffset: widowOffset,
          cursor: cursor,
        ),
    ];
    final span = TextSpan(
      children: widget.composer.compose(
        projected,
        style: widget.style,
        previous: previous,
        offset: widget.documentOffset + start,
      ),
    );
    return _RichParagraphProjection(
      span: span,
      text: span.toPlainText(),
      sourceLength: end - start,
      leadingPrevious: previous,
      pieces: List.unmodifiable(cursor.pieces),
    );
  }

  Inline _projectRun(
    Inline run, {
    required int rangeStart,
    required int? widowOffset,
    required _RichProjectionCursor cursor,
  }) {
    switch (run) {
      case TextRun(:final text):
        final sourceStart = cursor.sourceOffset;
        var displaySource = text;
        final globalStart = rangeStart + sourceStart;
        if (widowOffset != null &&
            widowOffset >= globalStart &&
            widowOffset < globalStart + text.length) {
          final local = widowOffset - globalStart;
          displaySource =
              '${text.substring(0, local)}\u00A0${text.substring(local + 1)}';
        }
        final projection = TypographicProjection.of(
          displaySource,
          previous: cursor.previous,
        );
        cursor.add(
          _TypographicRichPiece(
            sourceStart: sourceStart,
            displayStart: cursor.displayOffset,
            projection: projection,
          ),
          sourceLength: text.length,
          displayLength: projection.text.length,
          previous: projection.previousDisplayAt(projection.text.length),
        );
        return TextRun(projection.text);

      case CodeRun(:final text):
        cursor.addIdentity(text);
        return run;

      case LineBreakRun():
        cursor.addIdentity('\n');
        return run;

      case MarkedRun(:final mark, :final children):
        return MarkedRun(mark, [
          for (final child in children)
            _projectRun(
              child,
              rangeStart: rangeStart,
              widowOffset: widowOffset,
              cursor: cursor,
            ),
        ]);

      case LinkRun(:final href, :final title, :final children):
        return LinkRun(
          href: href,
          title: title,
          children: [
            for (final child in children)
              _projectRun(
                child,
                rangeStart: rangeStart,
                widowOffset: widowOffset,
                cursor: cursor,
              ),
          ],
        );

      case MathRun() ||
          FootnoteReferenceRun() ||
          FootnoteBackReferenceRun() ||
          ImageRun():
        throw StateError('Unsupported inline content escaped range indexing.');
    }
  }
}

final class _RichProjectionCursor {
  final List<_RichProjectionPiece> pieces = [];
  int sourceOffset = 0;
  int displayOffset = 0;
  String? previous;

  _RichProjectionCursor(this.previous);

  void add(
    _RichProjectionPiece piece, {
    required int sourceLength,
    required int displayLength,
    required String? previous,
  }) {
    pieces.add(piece);
    sourceOffset += sourceLength;
    displayOffset += displayLength;
    this.previous = previous;
  }

  void addIdentity(String text) {
    final piece = _IdentityRichPiece(
      sourceStart: sourceOffset,
      displayStart: displayOffset,
      text: text,
      leadingPrevious: previous,
    );
    add(
      piece,
      sourceLength: text.length,
      displayLength: text.length,
      previous: piece.previousDisplayAt(text.length),
    );
  }
}

final class _RichParagraphProjection implements WindowedParagraphProjection {
  @override
  final InlineSpan span;
  @override
  final String text;
  final int sourceLength;
  final String? leadingPrevious;
  final List<_RichProjectionPiece> pieces;

  const _RichParagraphProjection({
    required this.span,
    required this.text,
    required this.sourceLength,
    required this.leadingPrevious,
    required this.pieces,
  });

  @override
  int sourceOffsetAt(int displayOffset) {
    RangeError.checkValueInInterval(
      displayOffset,
      0,
      text.length,
      'displayOffset',
    );
    if (displayOffset == text.length) return sourceLength;
    final piece = pieces[_pieceAtOrBefore(displayOffset)];
    return piece.sourceStart +
        piece.sourceOffsetAt(displayOffset - piece.displayStart);
  }

  @override
  String? previousDisplayAt(int displayOffset) {
    RangeError.checkValueInInterval(
      displayOffset,
      0,
      text.length,
      'displayOffset',
    );
    if (displayOffset == 0) return leadingPrevious;
    final piece = pieces[_pieceBefore(displayOffset)];
    return piece.previousDisplayAt(displayOffset - piece.displayStart);
  }

  int _pieceAtOrBefore(int displayOffset) {
    var low = 0;
    var high = pieces.length;
    while (low < high) {
      final middle = low + ((high - low) >> 1);
      if (pieces[middle].displayStart <= displayOffset) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    return low - 1;
  }

  int _pieceBefore(int displayOffset) {
    var low = 0;
    var high = pieces.length;
    while (low < high) {
      final middle = low + ((high - low) >> 1);
      if (pieces[middle].displayStart < displayOffset) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    return low - 1;
  }
}

sealed class _RichProjectionPiece {
  final int sourceStart;
  final int displayStart;

  const _RichProjectionPiece({
    required this.sourceStart,
    required this.displayStart,
  });

  int sourceOffsetAt(int displayOffset);
  String? previousDisplayAt(int displayOffset);
}

final class _TypographicRichPiece extends _RichProjectionPiece {
  final TypographicProjection projection;

  const _TypographicRichPiece({
    required super.sourceStart,
    required super.displayStart,
    required this.projection,
  });

  @override
  int sourceOffsetAt(int displayOffset) =>
      projection.sourceOffsetAt(displayOffset);

  @override
  String? previousDisplayAt(int displayOffset) =>
      projection.previousDisplayAt(displayOffset);
}

final class _IdentityRichPiece extends _RichProjectionPiece {
  final String text;
  final String? leadingPrevious;

  const _IdentityRichPiece({
    required super.sourceStart,
    required super.displayStart,
    required this.text,
    required this.leadingPrevious,
  });

  @override
  int sourceOffsetAt(int displayOffset) {
    RangeError.checkValueInInterval(
      displayOffset,
      0,
      text.length,
      'displayOffset',
    );
    return displayOffset;
  }

  @override
  String? previousDisplayAt(int displayOffset) {
    RangeError.checkValueInInterval(
      displayOffset,
      0,
      text.length,
      'displayOffset',
    );
    if (displayOffset == 0) return leadingPrevious;
    final last = text.codeUnitAt(displayOffset - 1);
    if (last >= 0xDC00 && last <= 0xDFFF && displayOffset >= 2) {
      final first = text.codeUnitAt(displayOffset - 2);
      if (first >= 0xD800 && first <= 0xDBFF) {
        return text.substring(displayOffset - 2, displayOffset);
      }
    }
    return text.substring(displayOffset - 1, displayOffset);
  }
}
