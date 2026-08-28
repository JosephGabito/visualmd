/// Turns a writer's keyboard punctuation into a typographer's.
///
/// Straight quotes are hatch marks — they mean inches and feet. A reader
/// never notices proper quotes, dashes and ellipses; they notice their
/// absence, as a faint cheapness in the page.
///
/// This is presentation, not domain: the document's text is unchanged, only
/// the shapes it is set in.
abstract final class TypographicPunctuation {
  static const leftDouble = '“'; // “
  static const rightDouble = '”'; // ”
  static const leftSingle = '‘'; // ‘
  static const rightSingle = '’'; // ’ (also the apostrophe)
  static const enDash = '–'; // –
  static const emDash = '—'; // —
  static const ellipsis = '…'; // …

  /// True when a quote at this position opens rather than closes.
  ///
  /// A quote opens when nothing precedes it, or what precedes it is a space
  /// or an opening bracket — otherwise it closes, which also makes every
  /// apostrophe inside a word a right single quote, as it should be.
  static bool opensAfter(String? previous) {
    if (previous == null || previous.isEmpty) return true;
    return _openers.contains(previous);
  }

  static const _openers = {
    ' ',
    '\t',
    '\n',
    '(',
    '[',
    '{',
    '<',
    '—',
    '–',
    '“',
    '‘',
    '/',
  };

  /// The mark to set for a straight quote, given what came before it.
  static String quote(String straight, String? previous) {
    final opens = opensAfter(previous);
    return switch (straight) {
      '"' => opens ? leftDouble : rightDouble,
      _ => opens ? leftSingle : rightSingle,
    };
  }

  /// The mark to set for a run of hyphens: two make an en dash, three an em.
  static String dash(String hyphens) => hyphens.length >= 3 ? emDash : enDash;
}

/// Display punctuation with exact authored-source boundary recovery.
///
/// Most substitutions preserve length. Dash and ellipsis runs contract several
/// source code units into one display code unit, so only their ending deltas
/// need storage. A displayed selection boundary maps back to source in
/// logarithmic time without allocating one integer per character.
final class TypographicProjection {
  final String source;
  final String text;
  final String? _previous;
  final List<_ProjectionBoundary> _boundaries;

  const TypographicProjection._(
    this.source,
    this.text,
    this._previous,
    this._boundaries,
  );

  /// Projects one source range with the displayed character to its left.
  ///
  /// [previous] makes independently projected ranges compose exactly like one
  /// continuous paragraph. A viewport can therefore project only its bounded
  /// source window without guessing whether an opening quote at the edge is
  /// really an apostrophe or closing quote in the complete document.
  factory TypographicProjection.of(String source, {String? previous}) {
    final output = StringBuffer();
    final boundaries = <_ProjectionBoundary>[];
    var before = previous;
    var sourceOffset = 0;
    var displayOffset = 0;

    while (sourceOffset < source.length) {
      final unit = source.codeUnitAt(sourceOffset);
      var consumed = 1;
      var value = String.fromCharCode(unit);

      if (unit == 34 || unit == 39) {
        value = TypographicPunctuation.quote(value, before);
      } else if (unit == 45) {
        final run = _runOf(source, sourceOffset, 45);
        if (run >= 2) {
          consumed = run;
          value = TypographicPunctuation.dash('-' * run);
        }
      } else if (unit == 46 && _runOf(source, sourceOffset, 46) >= 3) {
        consumed = 3;
        value = TypographicPunctuation.ellipsis;
      } else if (_isHighSurrogate(unit) &&
          sourceOffset + 1 < source.length &&
          _isLowSurrogate(source.codeUnitAt(sourceOffset + 1))) {
        consumed = 2;
        value = source.substring(sourceOffset, sourceOffset + 2);
      }

      output.write(value);
      sourceOffset += consumed;
      displayOffset += value.length;
      if (sourceOffset - displayOffset !=
          (boundaries.isEmpty ? 0 : boundaries.last.delta)) {
        boundaries.add(
          _ProjectionBoundary(
            displayOffset: displayOffset,
            sourceOffset: sourceOffset,
          ),
        );
      }
      before = value;
    }

    return TypographicProjection._(
      source,
      output.toString(),
      previous,
      List.unmodifiable(boundaries),
    );
  }

  /// The complete displayed character immediately before [displayOffset].
  ///
  /// Offset zero returns the context supplied to [TypographicProjection.of].
  /// Later offsets preserve a surrogate pair as one character so the returned
  /// value can safely seed the next bounded projection.
  String? previousDisplayAt(int displayOffset) {
    RangeError.checkValueInInterval(
      displayOffset,
      0,
      text.length,
      'displayOffset',
    );
    if (displayOffset == 0) return _previous;
    final last = text.codeUnitAt(displayOffset - 1);
    if (_isLowSurrogate(last) && displayOffset >= 2) {
      final first = text.codeUnitAt(displayOffset - 2);
      if (_isHighSurrogate(first)) {
        return text.substring(displayOffset - 2, displayOffset);
      }
    }
    return text.substring(displayOffset - 1, displayOffset);
  }

  /// The source boundary represented by [displayOffset].
  int sourceOffsetAt(int displayOffset) {
    RangeError.checkValueInInterval(
      displayOffset,
      0,
      text.length,
      'displayOffset',
    );
    var low = 0;
    var high = _boundaries.length;
    while (low < high) {
      final middle = low + ((high - low) >> 1);
      if (_boundaries[middle].displayOffset <= displayOffset) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    final delta = low == 0 ? 0 : _boundaries[low - 1].delta;
    return displayOffset + delta;
  }

  static int _runOf(String source, int start, int unit) {
    var length = 0;
    while (start + length < source.length &&
        source.codeUnitAt(start + length) == unit) {
      length++;
    }
    return length;
  }

  static bool _isHighSurrogate(int unit) => unit >= 0xD800 && unit <= 0xDBFF;

  static bool _isLowSurrogate(int unit) => unit >= 0xDC00 && unit <= 0xDFFF;
}

final class _ProjectionBoundary {
  final int displayOffset;
  final int sourceOffset;

  const _ProjectionBoundary({
    required this.displayOffset,
    required this.sourceOffset,
  });

  int get delta => sourceOffset - displayOffset;
}
