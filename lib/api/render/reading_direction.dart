import 'package:flutter/widgets.dart';

import 'strong_bidi_classes.g.dart';

/// Resolves the base direction of authored reading text.
///
/// A heading may mix scripts, identifiers and punctuation. Its paragraph
/// direction comes from the first strongly directional character, not from
/// the application chrome or from whichever script occupies the most space.
/// The strong classes are generated from Unicode rather than inferred from
/// UTF-16 ranges, so an emoji or an astral script cannot corrupt the answer.
abstract final class ReadingDirection {
  static TextDirection of(String text, {required TextDirection fallback}) {
    var isolateDepth = 0;
    for (final codePoint in text.runes) {
      if (_isolateInitiators.contains(codePoint)) {
        isolateDepth++;
        continue;
      }
      if (codePoint == _popDirectionalIsolate) {
        if (isolateDepth > 0) isolateDepth--;
        continue;
      }
      if (isolateDepth > 0) continue;

      switch (StrongBidiClasses.of(codePoint)) {
        case StrongBidiClasses.rtl:
          return TextDirection.rtl;
        case StrongBidiClasses.ltr:
          return TextDirection.ltr;
      }
    }
    return fallback;
  }

  static const _isolateInitiators = {0x2066, 0x2067, 0x2068};
  static const _popDirectionalIsolate = 0x2069;
}
