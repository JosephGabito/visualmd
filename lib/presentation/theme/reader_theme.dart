import 'dart:ui' show Brightness;

import 'theme_format_exception.dart';
import 'theme_palette.dart';
import 'theme_typefaces.dart';

/// A theme the reader can wear: semantic colour tokens plus three typefaces.
/// Themes are data, not code. Built-ins are Dart constants; user themes are
/// JSON documents with the same shape (see [ReaderTheme.fromJson]).
final class ReaderTheme {
  static const schemaVersion = 1;

  final String id;
  final String name;
  final Brightness brightness;
  final ThemePalette palette;
  final ThemeTypefaces typefaces;

  /// Where the theme came from: `built-in`, or the file it was read from.
  final String origin;

  const ReaderTheme({
    required this.id,
    required this.name,
    required this.brightness,
    required this.palette,
    this.typefaces = ThemeTypefaces.library,
    this.origin = 'built-in',
  });

  bool get isDark => brightness == Brightness.dark;

  /// Parses the JSON document format. Throws [ThemeFormatException] with a
  /// reason a theme author can act on.
  factory ReaderTheme.fromJson(
    Map<String, Object?> json, {
    String origin = 'file',
  }) {
    String text(String key) {
      final value = json[key];
      if (value is! String || value.trim().isEmpty) {
        throw ThemeFormatException('"$key" must be a non-empty string');
      }
      return value.trim();
    }

    final id = text('id');
    if (!RegExp(r'^[a-z0-9][a-z0-9-]*$').hasMatch(id)) {
      throw ThemeFormatException(
        '"id" must be lowercase letters, digits and hyphens: "$id"',
      );
    }
    final brightness = switch (text('brightness')) {
      'light' => Brightness.light,
      'dark' => Brightness.dark,
      final other => throw ThemeFormatException(
        '"brightness" must be "light" or "dark", not "$other"',
      ),
    };
    final paletteJson = json['palette'];
    if (paletteJson is! Map<String, Object?>) {
      throw const ThemeFormatException('"palette" must be an object');
    }
    final typefacesJson = json['typefaces'];
    if (typefacesJson != null && typefacesJson is! Map<String, Object?>) {
      throw const ThemeFormatException(
        '"typefaces" must be an object when present',
      );
    }

    return ReaderTheme(
      id: id,
      name: text('name'),
      brightness: brightness,
      palette: ThemePalette.fromJson(paletteJson),
      typefaces: typefacesJson == null
          ? ThemeTypefaces.library
          : ThemeTypefaces.fromJson(typefacesJson as Map<String, Object?>),
      origin: origin,
    );
  }

  Map<String, Object?> toJson() => {
    'schema': schemaVersion,
    'id': id,
    'name': name,
    'brightness': brightness == Brightness.dark ? 'dark' : 'light',
    'palette': palette.toJson(),
    'typefaces': typefaces.toJson(),
  };

  @override
  String toString() => 'ReaderTheme($id)';
}
