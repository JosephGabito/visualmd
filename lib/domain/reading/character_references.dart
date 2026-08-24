import 'named_character_references.g.dart';

/// Resolves the character encodings CommonMark admits into ordinary text.
///
/// Decoding deliberately lives in the framework-free domain because the
/// outline must derive the same reading text as the page adapter. Named
/// references come from WHATWG's complete semicolon-terminated HTML table;
/// decimal and hexadecimal references use CommonMark's bounded grammar.
abstract final class CharacterReferences {
  static final _syntax = RegExp(
    r'&(?:([A-Za-z0-9]+)|#([0-9]{1,7})|#[xX]([A-Fa-f0-9]{1,6}));',
  );

  /// Replaces valid references and leaves every non-reference untouched.
  static String decode(String source) =>
      source.replaceAllMapped(_syntax, (match) {
        final name = match[1];
        if (name != null) {
          return namedCharacterReferences[match[0]!] ?? match[0]!;
        }

        final decimal = match[2];
        final value = decimal == null
            ? int.parse(match[3]!, radix: 16)
            : int.parse(decimal);
        return decimal == null ? _scalar(value) : _decimalScalar(value);
      });

  // Keep the outline identical to package:markdown's page parser, which
  // rejects the first two decimal control values while its hexadecimal path
  // accepts U+0001. That distinction is observable in the resolved heading.
  static String _decimalScalar(int value) =>
      value <= 1 ? '\ufffd' : _scalar(value);

  static String _scalar(int value) {
    if (value == 0 ||
        value > 0x10ffff ||
        (value >= 0xd800 && value <= 0xdfff)) {
      return '\ufffd';
    }
    return String.fromCharCode(value);
  }
}
