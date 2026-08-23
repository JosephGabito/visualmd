import 'dart:convert';
import 'dart:ui' show Brightness;

import 'built_in_themes.dart';
import 'reader_theme.dart';
import 'theme_format_exception.dart';
import 'theme_choice.dart';

/// A user theme file that could not be used, and why.
final class ThemeLoadError {
  final String origin;
  final String reason;
  const ThemeLoadError(this.origin, this.reason);

  @override
  String toString() => '$origin: $reason';
}

/// Every theme the reader can wear: built-ins first, then user themes.
/// A user theme with a built-in's id replaces it — that is how you tweak one.
final class ThemeRegistry {
  final Map<String, ReaderTheme> _themes;
  final List<ThemeLoadError> errors;

  ThemeRegistry._(this._themes, this.errors);

  factory ThemeRegistry({
    List<ReaderTheme> builtIn = BuiltInThemes.all,
    List<ReaderTheme> user = const [],
    List<ThemeLoadError> errors = const [],
  }) {
    final themes = <String, ReaderTheme>{};
    for (final theme in builtIn) {
      themes[theme.id] = theme;
    }
    for (final theme in user) {
      themes[theme.id] = theme;
    }
    return ThemeRegistry._(themes, List.unmodifiable(errors));
  }

  /// Builds a registry from raw theme documents (JSON text), keeping the
  /// ones that parse and reporting the ones that do not.
  factory ThemeRegistry.fromDocuments(
    Iterable<({String origin, String json})> documents,
  ) {
    final user = <ReaderTheme>[];
    final errors = <ThemeLoadError>[];
    for (final doc in documents) {
      try {
        final decoded = jsonDecode(doc.json);
        if (decoded is! Map<String, Object?>) {
          throw const ThemeFormatException('top level must be an object');
        }
        user.add(ReaderTheme.fromJson(decoded, origin: doc.origin));
      } on ThemeFormatException catch (e) {
        errors.add(ThemeLoadError(doc.origin, e.reason));
      } on FormatException catch (e) {
        errors.add(ThemeLoadError(doc.origin, 'not valid JSON: ${e.message}'));
      }
    }
    return ThemeRegistry(user: user, errors: errors);
  }

  List<ReaderTheme> get all => List.unmodifiable(_themes.values);

  List<ReaderTheme> get light => all.where((t) => !t.isDark).toList();

  List<ReaderTheme> get dark => all.where((t) => t.isDark).toList();

  ReaderTheme? byId(String id) => _themes[id];

  /// The default pair, always present.
  FollowSystem get systemPair => FollowSystem(
    light: BuiltInThemes.defaultLight.id,
    dark: BuiltInThemes.defaultDark.id,
  );

  /// Resolves a choice for the system brightness, falling back to the
  /// default of that brightness when the chosen theme is gone.
  ReaderTheme resolve(ThemeChoice choice, Brightness system) =>
      byId(choice.idFor(system)) ??
      (system == Brightness.dark
          ? BuiltInThemes.defaultDark
          : BuiltInThemes.defaultLight);
}
