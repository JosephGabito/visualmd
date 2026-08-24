import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' show Bidi;

/// Resolves the base direction of authored reading text.
///
/// A heading may mix scripts, identifiers and punctuation. Its paragraph
/// direction comes from the first strongly directional character, not from
/// the application chrome or from whichever script occupies the most space.
abstract final class ReadingDirection {
  static TextDirection of(String text, {required TextDirection fallback}) {
    if (Bidi.startsWithRtl(text)) return TextDirection.rtl;
    if (Bidi.startsWithLtr(text)) return TextDirection.ltr;
    return fallback;
  }
}
