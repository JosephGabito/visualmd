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
  final List<_ProjectionBoundary> _boundaries;

  const TypographicProjection._(this.source, this.text, this._boundaries);

  factory TypographicProjection.of(String source) {
    final output = StringBuffer();
    final boundaries = <_ProjectionBoundary>[];
    String? previous;
    var sourceOffset = 0;
    var displayOffset = 0;

    while (sourceOffset < source.length) {
      final unit = source.codeUnitAt(sourceOffset);
      var consumed = 1;
      var value = String.fromCharCode(unit);

      if (unit == 34 || unit == 39) {
        value = TypographicPunctuation.quote(value, previous);
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
      previous = value;
    }

    return TypographicProjection._(
      source,
      output.toString(),
      List.unmodifiable(boundaries),
    );
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
