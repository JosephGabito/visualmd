import 'package:flutter/material.dart';

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
  late InlineRangeIndex _index;

  @override
  void initState() {
    super.initState();
    _index = InlineRangeIndex(widget.content);
  }

  @override
  void didUpdateWidget(WindowedRichParagraph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sourceRevision != widget.sourceRevision ||
        !identical(oldWidget.content, widget.content)) {
      _index = InlineRangeIndex(widget.content);
    }
  }

  @override
  Widget build(BuildContext context) => WindowedPlainParagraph(
    source: _index.source,
    sourceRevision: widget.sourceRevision,
    style: widget.style,
    textScaler: widget.textScaler,
    strutStyle: widget.strutStyle,
    textDirection: ReadingDirection.of(
      _index.source,
      fallback: Directionality.of(context),
    ),
    finalized: widget.finalized,
    selectionColor: widget.selectionColor,
    rangeProjector: _projectRange,
    widowOffsetFor: (_) => _index.widowOffset,
    selectionIdentity: widget.selectionIdentity,
    selectionOrder: widget.selectionOrder,
    debugOnSourceIndexed: widget.debugOnSourceIndexed,
    debugOnInitialIndexStep: widget.debugOnInitialIndexStep,
  );

  WindowedParagraphProjection _projectRange({
    required int start,
    required int end,
    required String? previous,
    required int? widowOffset,
  }) {
    final cursor = _RichProjectionCursor(previous);
    final projected = [
      for (final run in _index.slice(start, end))
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
