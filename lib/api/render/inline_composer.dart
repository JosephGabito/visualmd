import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../application/ports/document_image_loader.dart';
import '../../domain/library/document_id.dart';
import '../../domain/reading/content/inline.dart';
import '../../domain/search/search_result.dart';
import '../../presentation/code/code_highlighter.dart';
import '../../presentation/theme/typographic_punctuation.dart';
import 'reading_theme.dart';
import '../widgets/document_image.dart';
import '../widgets/math_expression.dart';

/// Turns the domain's runs into spans, and sets the punctuation properly on
/// the way past.
///
/// The document keeps what the author typed; the page shows what a
/// typographer would have set. Straight quotes become the marks they stand
/// for, pairs of hyphens become dashes, three dots become an ellipsis — and
/// none of it touches code, which is composed verbatim.
final class InlineComposer {
  final ReadingTheme theme;
  final DocumentId? document;
  final DocumentImageLoader? imageLoader;
  final void Function(String href)? onTapLink;
  final List<TextMatch> matches;
  final int activeMatch;

  const InlineComposer({
    required this.theme,
    this.document,
    this.imageLoader,
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

  /// Composes the exact code source while layering two independent meanings:
  /// syntax changes the foreground, and document search changes the ground.
  ///
  /// Source offsets remain the authority. Any gap not covered by a contributed
  /// token is emitted in [style], so highlighting can fail partially without
  /// removing, repeating or rewriting a character.
  List<InlineSpan> highlightedVerbatim(
    String text, {
    required TextStyle style,
    required CodeHighlighting? highlighting,
    required TextStyle Function(CodeHighlightToken token) styleFor,
    int offset = 0,
  }) {
    if (text.isEmpty) return const [];
    final tokens = [
      for (final token in highlighting?.tokens ?? const <CodeHighlightToken>[])
        if (token.start >= 0 &&
            token.end <= text.length &&
            token.start < token.end)
          token,
    ]..sort((a, b) => a.start.compareTo(b.start));

    final boundaries = <int>{0, text.length};
    for (final token in tokens) {
      final range = CharacterRange.at(text, token.start, token.end);
      boundaries
        ..add(range.stringBeforeLength)
        ..add(text.length - range.stringAfterLength);
    }
    for (final match in matches) {
      final start = (match.start - offset).clamp(0, text.length);
      final end = (match.end - offset).clamp(0, text.length);
      if (start < end) {
        final range = CharacterRange.at(text, start, end);
        boundaries
          ..add(range.stringBeforeLength)
          ..add(text.length - range.stringAfterLength);
      }
    }
    final cuts = boundaries.toList()..sort();

    final spans = <InlineSpan>[];
    for (var i = 0; i + 1 < cuts.length; i++) {
      final start = cuts[i];
      final end = cuts[i + 1];
      if (start == end) continue;
      final tokenIndex = tokens.indexWhere(
        (token) => token.start < end && token.end > start,
      );
      final base = tokenIndex < 0 ? style : styleFor(tokens[tokenIndex]);
      final matchIndex = matches.indexWhere(
        (match) => match.overlaps(offset + start, offset + end),
      );
      final runStyle = _highlighted(base, matchIndex);
      final value = text.substring(start, end);

      final previous = spans.isEmpty ? null : spans.last;
      if (previous is TextSpan && previous.style == runStyle) {
        spans[spans.length - 1] = TextSpan(
          text: '${previous.text ?? ''}$value',
          style: runStyle,
        );
      } else {
        spans.add(TextSpan(text: value, style: runStyle));
      }
    }
    return spans;
  }

  /// Composes one source window without making the complete code block a text
  /// layout object.
  ///
  /// Highlight ranges remain relative to [source], while document search
  /// ranges remain relative to the complete document. Only tokens intersecting
  /// the requested window are copied and rebased. The binary seek matters for
  /// long highlighted blocks: scrolling to the last page must not walk every
  /// token that precedes it.
  List<InlineSpan> highlightedVerbatimRange(
    String source, {
    required int start,
    required int end,
    required TextStyle style,
    required CodeHighlighting? highlighting,
    required TextStyle Function(CodeHighlightToken token) styleFor,
    int offset = 0,
  }) {
    assert(start >= 0 && start <= end && end <= source.length);
    final text = source.substring(start, end);
    final all = highlighting?.tokens ?? const <CodeHighlightToken>[];
    var low = 0;
    var high = all.length;
    while (low < high) {
      final middle = low + ((high - low) >> 1);
      if (all[middle].end <= start) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    final tokens = <CodeHighlightToken>[];
    for (var index = low; index < all.length; index++) {
      final token = all[index];
      if (token.start >= end) break;
      final clippedStart = token.start.clamp(start, end);
      final clippedEnd = token.end.clamp(start, end);
      if (clippedStart < clippedEnd) {
        tokens.add(
          CodeHighlightToken(
            start: clippedStart - start,
            end: clippedEnd - start,
            role: token.role,
            foreground: token.foreground,
          ),
        );
      }
    }
    return highlightedVerbatim(
      text,
      style: style,
      highlighting: highlighting == null ? null : CodeHighlighting(tokens),
      styleFor: styleFor,
      offset: offset + start,
    );
  }

  List<InlineSpan> _compose(
    List<Inline> runs, {
    TextStyle? style,
    String? previous,
    required _TextCursor cursor,
    List<InlineMark> marks = const [],
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
          marks: marks,
        ),
      );
    }
    return spans;
  }

  /// The last grapheme composed so far, which decides whether the next
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
    return text == null || text.isEmpty ? null : text.characters.last;
  }

  List<InlineSpan> _run(
    Inline run,
    TextStyle base, {
    String? previous,
    required _TextCursor cursor,
    required List<InlineMark> marks,
  }) {
    switch (run) {
      case TextRun(:final text):
        return _text(text, base, cursor, previous: previous);

      case CodeRun(:final text):
        return _text(
          text,
          _markedCodeStyle(base, marks),
          cursor,
          previous: previous,
          code: true,
          setPunctuation: false,
        );

      case MathRun(:final source):
        final start = cursor.offset;
        cursor.offset += source.length;
        final matchIndex = matches.indexWhere(
          (match) => match.overlaps(start, start + source.length),
        );
        return [
          readableMathSpan(
            source: source,
            style: base,
            fontSize: theme.mathSizeFor(base),
            background: matchIndex < 0
                ? null
                : (matchIndex == activeMatch
                      ? theme.palette.accentSoft
                      : theme.palette.selection),
          ),
        ];

      case MarkedRun(:final mark, :final children):
        final marked = switch (mark) {
          // Italic is the standard mark of emphasis, and one mark is enough.
          InlineMark.emphasis => base.copyWith(fontStyle: FontStyle.italic),
          InlineMark.strong => base.copyWith(fontWeight: FontWeight.w700),
          // A line through the type already says that the words were deleted.
          // Keeping their inherited ink avoids adding a second, dimming cue.
          InlineMark.strikethrough => _withDecoration(
            base,
            TextDecoration.lineThrough,
          ),
          // These OpenType substitutions use glyphs drawn by the face rather
          // than scaled widgets. Size and leading therefore stay on the
          // surrounding role's baseline grid.
          InlineMark.subscript => _withFontFeature(
            base,
            const FontFeature.subscripts(),
          ),
          InlineMark.superscript => _withFontFeature(
            base,
            const FontFeature.superscripts(),
          ),
          // GitHub documents `ins` as underline. Inherited ink keeps it
          // editorial; links remain the accented, interactive underline.
          InlineMark.insertion => _withDecoration(
            base,
            TextDecoration.underline,
          ),
        };
        return [
          TextSpan(
            children: _compose(
              children,
              style: marked,
              previous: previous,
              cursor: cursor,
              marks: [...marks, mark],
            ),
          ),
        ];

      case LinkRun(:final href, :final children):
        final tap = onTapLink;
        final recognizer = tap == null
            ? null
            : (TapGestureRecognizer()..onTap = () => tap(href));
        final composed = _compose(
          children,
          style: theme.linkFor(base),
          previous: previous,
          cursor: cursor,
          marks: marks,
        );
        return [
          _LinkTextSpan(
            // Semantics and hit testing own the glyphs the page actually set,
            // including typographic quotes and collapsed dash runs.
            label: TextSpan(children: composed).toPlainText(),
            children: composed,
            recognizer: recognizer,
            mouseCursor: SystemMouseCursors.click,
          ),
        ];

      case FootnoteReferenceRun(:final number, :final definitionAnchor):
        final text = number.toString();
        final start = cursor.offset;
        cursor.offset += text.length;
        final matchIndex = matches.indexWhere(
          (match) => match.overlaps(start, start + text.length),
        );
        final linked = _withFontFeature(
          theme.linkFor(base),
          const FontFeature.superscripts(),
        );
        final tap = onTapLink;
        return [
          _LinkTextSpan(
            label: text,
            accessibleLabel: 'Footnote $number',
            children: [
              TextSpan(text: text, style: _highlighted(linked, matchIndex)),
            ],
            recognizer: tap == null
                ? null
                : (TapGestureRecognizer()
                    ..onTap = () => tap('#$definitionAnchor')),
            mouseCursor: SystemMouseCursors.click,
          ),
        ];

      case FootnoteBackReferenceRun(
        :final number,
        :final occurrence,
        :final referenceAnchor,
        :final text,
      ):
        final start = cursor.offset;
        cursor.offset += text.length;
        final matchIndex = matches.indexWhere(
          (match) => match.overlaps(start, start + text.length),
        );
        final linked = theme.linkFor(base);
        final occurrenceText = occurrence > 1 ? occurrence.toString() : '';
        final arrowText = occurrenceText.isEmpty
            ? text
            : text.substring(0, text.length - occurrenceText.length);
        final tap = onTapLink;
        return [
          _LinkTextSpan(
            label: text,
            accessibleLabel: occurrence == 1
                ? 'Return to footnote reference $number'
                : 'Return to footnote reference $number, occurrence $occurrence',
            children: [
              TextSpan(
                text: arrowText,
                style: _highlighted(linked, matchIndex),
              ),
              if (occurrenceText.isNotEmpty)
                TextSpan(
                  text: occurrenceText,
                  style: _highlighted(
                    _withFontFeature(linked, const FontFeature.superscripts()),
                    matchIndex,
                  ),
                ),
            ],
            recognizer: tap == null
                ? null
                : (TapGestureRecognizer()
                    ..onTap = () => tap('#$referenceAnchor')),
            mouseCursor: SystemMouseCursors.click,
          ),
        ];

      case ImageRun(:final title, :final alt):
        final source = run.sourceFor(
          theme.isDark ? ImageColorScheme.dark : ImageColorScheme.light,
        );
        final uri = Uri.tryParse(source);
        final remote =
            uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
        if (!remote && (document == null || imageLoader == null)) {
          return _text(
            alt,
            base.copyWith(color: theme.palette.muted),
            cursor,
            previous: previous,
            setPunctuation: false,
          );
        }
        // The image occupies one inline placeholder in Flutter, while the
        // domain's reading text is its complete alternative. Advancing by the
        // alternative keeps search offsets after the image in source order.
        cursor.offset += alt.length;
        return [
          WidgetSpan(
            alignment: PlaceholderAlignment.top,
            style: base,
            child: DocumentImage(
              document: document,
              source: source,
              alt: alt,
              title: title,
              loader: imageLoader,
              theme: theme,
            ),
          ),
        ];

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

  static TextStyle _withFontFeature(TextStyle base, FontFeature feature) =>
      base.copyWith(
        fontFeatures: [
          ...?base.fontFeatures?.where(
            (inherited) =>
                inherited.feature != 'subs' && inherited.feature != 'sups',
          ),
          feature,
        ],
      );

  static TextStyle _withDecoration(TextStyle base, TextDecoration decoration) =>
      base.copyWith(
        decoration: TextDecoration.combine([
          if (base.decoration != null) base.decoration!,
          decoration,
        ]),
      );

  TextStyle _markedCodeStyle(TextStyle base, List<InlineMark> marks) {
    var style = theme.inlineCodeFor(base);
    for (final mark in marks) {
      style = switch (mark) {
        InlineMark.subscript => _withFontFeature(
          style,
          const FontFeature.subscripts(),
        ),
        InlineMark.superscript => _withFontFeature(
          style,
          const FontFeature.superscripts(),
        ),
        InlineMark.insertion => _withDecoration(
          style,
          TextDecoration.underline,
        ),
        _ => style,
      };
    }
    return style;
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
    // A style boundary inside a grapheme can prevent the text engine from
    // shaping its code points as one character. Search may legitimately find
    // one constituent, so composition expands that paint to the whole cluster.
    final graphemes = CharacterRange(text);
    while (graphemes.moveNext()) {
      final i = graphemes.stringBeforeLength;
      final character = graphemes.current;
      var consumed = character.length;
      var value = character;
      if (setPunctuation) {
        switch (character) {
          case '"' || "'":
            value = TypographicPunctuation.quote(character, before);
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
      before = value.characters.last;
      final skipped = consumed - character.length;
      if (skipped > 0) graphemes.moveNext(skipped);
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

/// A styled link that remains one interaction and one accessible phrase.
///
/// A normal child-only [TextSpan] paints its descendants correctly, but its
/// recognizer is absent from both hit testing and semantics because the parent
/// owns no text of its own. This span deliberately presents the descendants as
/// one logical run while leaving their styles available to the text engine.
final class _LinkTextSpan extends TextSpan {
  final String label;
  final String? accessibleLabel;

  const _LinkTextSpan({
    required this.label,
    this.accessibleLabel,
    required super.children,
    required super.recognizer,
    required super.mouseCursor,
  });

  @override
  bool visitChildren(InlineSpanVisitor visitor) => visitor(this);

  @override
  InlineSpan? getSpanForPositionVisitor(
    TextPosition position,
    Accumulator offset,
  ) {
    final start = offset.value;
    final end = start + label.length;
    final target = position.offset;
    final owns =
        (target == start && position.affinity == TextAffinity.downstream) ||
        (start < target && target < end) ||
        (target == end && position.affinity == TextAffinity.upstream);
    offset.increment(label.length);
    return owns ? this : null;
  }

  @override
  int? codeUnitAtVisitor(int index, Accumulator offset) {
    final local = index - offset.value;
    offset.increment(label.length);
    return local >= 0 && local < label.length ? label.codeUnitAt(local) : null;
  }

  @override
  void computeToPlainText(
    StringBuffer buffer, {
    bool includeSemanticsLabels = true,
    bool includePlaceholders = true,
  }) {
    buffer.write(label);
  }

  @override
  void computeSemanticsInformation(
    List<InlineSpanSemanticsInformation> collector, {
    ui.Locale? inheritedLocale,
    bool inheritedSpellOut = false,
  }) {
    collector.add(
      InlineSpanSemanticsInformation(
        label,
        recognizer: recognizer,
        semanticsLabel: accessibleLabel,
        stringAttributes: [
          if (inheritedSpellOut && label.isNotEmpty)
            ui.SpellOutStringAttribute(
              range: TextRange(start: 0, end: label.length),
            ),
          if (inheritedLocale != null && label.isNotEmpty)
            ui.LocaleStringAttribute(
              locale: inheritedLocale,
              range: TextRange(start: 0, end: label.length),
            ),
        ],
      ),
    );
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
