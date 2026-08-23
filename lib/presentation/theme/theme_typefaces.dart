import 'theme_format_exception.dart';

/// Family names for the three voices of the page. Families are resolved by
/// the font layer at render time; unknown names fall back to the library set.
final class ThemeTypefaces {
  final String serif;
  final String sans;
  final String mono;

  const ThemeTypefaces({
    required this.serif,
    required this.sans,
    required this.mono,
  });

  /// The library's own voices.
  ///
  /// Alegreya reads the page: a face drawn for literature, with the long
  /// extenders and the movement of a book rather than the even texture of a
  /// screen serif. Inter is the furniture — shelf, outline, controls — and
  /// never appears inside a document. JetBrains Mono carries code, where a
  /// letter has to be told from a digit.
  static const library = ThemeTypefaces(
    serif: 'Alegreya',
    sans: 'Inter',
    mono: 'JetBrains Mono',
  );

  factory ThemeTypefaces.fromJson(Map<String, Object?> json) {
    String family(String key, String fallback) {
      final value = json[key];
      if (value == null) return fallback;
      if (value is! String || value.trim().isEmpty) {
        throw ThemeFormatException(
          'typefaces."$key" must be a non-empty string',
        );
      }
      return value.trim();
    }

    return ThemeTypefaces(
      serif: family('serif', library.serif),
      sans: family('sans', library.sans),
      mono: family('mono', library.mono),
    );
  }

  Map<String, Object?> toJson() => {'serif': serif, 'sans': sans, 'mono': mono};
}
