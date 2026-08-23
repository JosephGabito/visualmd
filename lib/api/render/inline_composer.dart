import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../domain/reading/content/inline.dart';
import '../../domain/search/search_result.dart';
import '../../presentation/theme/typographic_punctuation.dart';
import 'reading_theme.dart';

/// Turns the domain's runs into spans, and sets the punctuation properly on
/// the way past.
///
/// The document keeps what the author typed; the page shows what a
/// typographer would have set. Straight quotes become the marks they stand
/// for, pairs of hyphens become dashes, three dots become an ellipsis — and
/// none of it touches code, which is composed verbatim.
final class InlineComposer {
  final ReadingTheme theme;
  final void Function(String href)? onTapLink;
  final List<TextMatch> matches;
  final int activeMatch;

  const InlineComposer({
    required this.theme,
    this.onTapLink,
    this.matches = const [],
    this.activeMatch = -1,
  });

  List<InlineSpan> compose(
    List<Inline> runs, {
    TextStyle? style,
    String? previous,
    int offset = 0,
  }) {
    final cursor = _TextCursor(offset);
    return _compose(runs, style: style, previous: previous, cursor: cursor);
  }

  List<InlineSpan> verbatim(
    String text, {
    required TextStyle style,
    int offset = 0,
  }) => _text(text, style, _TextCursor(offset), setPunctuation: false);

  List<InlineSpan> _compose(
    List<Inline> runs, {
    TextStyle? style,
    String? previous,
    required _TextCursor cursor,
  }) {
    final base = style ?? theme.body;
    final spans = <InlineSpan>[];
    for (var i = 0; i < runs.length; i++) {
      spans.addAll(
        _run(
          runs[i],
          base,
          previous: _tailOf(spans) ?? previous,
          cursor: cursor,
        ),
      );
    }
    return spans;
  }

  /// The last character composed so far, which decides whether the next
  /// quote opens or closes.
  String? _tailOf(List<InlineSpan> spans) {
    for (final span in spans.reversed) {
      final tail = _tailOfSpan(span);
      if (tail != null) return tail;
    }
    return null;
  }

  String? _tailOfSpan(InlineSpan span) {
    if (span is! TextSpan) return 'x';
    for (final child in (span.children ?? const <InlineSpan>[]).reversed) {
      final tail = _tailOfSpan(child);
      if (tail != null) return tail;
    }
    final text = span.text;
    return text == null || text.isEmpty ? null : text[text.length - 1];
  }

  List<InlineSpan> _run(
    Inline run,
    TextStyle base, {
    String? previous,
    required _TextCursor cursor,
  }) {
    switch (run) {
      case TextRun(:final text):
        return _text(text, base, cursor, previous: previous);

      case CodeRun(:final text):
        return _text(
          text,
          theme.inlineCodeFor(base),
          cursor,
          previous: previous,
          code: true,
          setPunctuation: false,
        );

      case MarkedRun(:final mark, :final children):
        final marked = switch (mark) {
          // Italic is the standard mark of emphasis, and one mark is enough.
          InlineMark.emphasis => base.copyWith(fontStyle: FontStyle.italic),
          InlineMark.strong => base.copyWith(fontWeight: FontWeight.w700),
          InlineMark.strikethrough => base.copyWith(
            decoration: TextDecoration.lineThrough,
            color: theme.palette.muted,
          ),
        };
        return [
          TextSpan(
            children: _compose(
              children,
              style: marked,
              previous: previous,
              cursor: cursor,
            ),
          ),
        ];

      case LinkRun(:final href, :final children, :final title):
        final tap = onTapLink;
        return [
          TextSpan(
            children: _compose(
              children,
              style: theme.linkFor(base),
              previous: previous,
              cursor: cursor,
            ),
            recognizer: tap == null
                ? null
                : (TapGestureRecognizer()..onTap = () => tap(href)),
            mouseCursor: SystemMouseCursors.click,
            semanticsLabel: title,
          ),
        ];

      case ImageRun(:final alt):
        // Images are not resolved yet; the alt text is what the author meant
        // the reader to get either way.
        return _text(
          alt,
          base.copyWith(color: theme.palette.muted),
          cursor,
          previous: previous,
          setPunctuation: false,
        );

      case LineBreakRun():
        return _text(
          '\n',
          base,
          cursor,
          previous: previous,
          setPunctuation: false,
        );
    }
  }

  List<InlineSpan> _text(
    String text,
    TextStyle base,
    _TextCursor cursor, {
    String? previous,
    bool code = false,
    bool setPunctuation = true,
  }) {
    final start = cursor.offset;
    cursor.offset += text.length;
    final chunks = <_StyledChunk>[];
    var before = previous;
    var i = 0;
    while (i < text.length) {
      var consumed = 1;
      var value = text[i];
      if (setPunctuation) {
        switch (text[i]) {
          case '"' || "'":
            value = TypographicPunctuation.quote(text[i], before);
          case '-' when _runOf(text, i, '-') >= 2:
            consumed = _runOf(text, i, '-');
            value = TypographicPunctuation.dash('-' * consumed);
          case '.' when _runOf(text, i, '.') >= 3:
            consumed = 3;
            value = TypographicPunctuation.ellipsis;
        }
      }
      final matchIndex = matches.indexWhere(
        (match) => match.overlaps(start + i, start + i + consumed),
      );
      if (chunks.isNotEmpty && chunks.last.matchIndex == matchIndex) {
        chunks.last.text.write(value);
      } else {
        chunks.add(_StyledChunk(matchIndex, StringBuffer(value)));
      }
      before = value[value.length - 1];
      i += consumed;
    }

    return [
      for (final chunk in chunks)
        code
            ? InlineCodeSpan(
                text: chunk.text.toString(),
                style: _highlighted(base, chunk.matchIndex),
              )
            : TextSpan(
                text: chunk.text.toString(),
                style: _highlighted(base, chunk.matchIndex),
              ),
    ];
  }

  TextStyle _highlighted(TextStyle base, int matchIndex) {
    if (matchIndex < 0) return base;
    return base.copyWith(
      backgroundColor: matchIndex == activeMatch
          ? theme.palette.accentSoft
          : theme.palette.selection,
    );
  }

  static int _runOf(String text, int start, String char) {
    var n = 0;
    while (start + n < text.length && text[start + n] == char) {
      n++;
    }
    return n;
  }
}

final class _TextCursor {
  int offset;
  _TextCursor(this.offset);
}

final class _StyledChunk {
  final int matchIndex;
  final StringBuffer text;

  _StyledChunk(this.matchIndex, this.text);
}

/// A selectable code run whose source text must remain byte-for-byte intact.
///
/// The type carries meaning that colour or decoration cannot: paragraph
/// setting may change, but widow binding must never rewrite an identifier,
/// command, or path the reader expects to copy exactly.
final class InlineCodeSpan extends TextSpan {
  const InlineCodeSpan({required super.text, required super.style});
}
