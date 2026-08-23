import 'dart:ui' show Brightness;

/// What the reader asked for: one theme regardless of the system, or a
/// light/dark pair that follows it.
sealed class ThemeChoice {
  const ThemeChoice();

  /// The theme id to use for the given system brightness.
  String idFor(Brightness system);

  Map<String, Object?> toJson();

  static ThemeChoice? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    return switch (json['mode']) {
      'fixed' when json['theme'] is String => FixedTheme(
        json['theme'] as String,
      ),
      'system' when json['light'] is String && json['dark'] is String =>
        FollowSystem(
          light: json['light'] as String,
          dark: json['dark'] as String,
        ),
      _ => null,
    };
  }
}

final class FixedTheme extends ThemeChoice {
  final String id;
  const FixedTheme(this.id);

  @override
  String idFor(Brightness system) => id;

  @override
  Map<String, Object?> toJson() => {'mode': 'fixed', 'theme': id};

  @override
  bool operator ==(Object other) => other is FixedTheme && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

final class FollowSystem extends ThemeChoice {
  final String light;
  final String dark;
  const FollowSystem({required this.light, required this.dark});

  @override
  String idFor(Brightness system) => system == Brightness.dark ? dark : light;

  @override
  Map<String, Object?> toJson() => {
    'mode': 'system',
    'light': light,
    'dark': dark,
  };

  @override
  bool operator ==(Object other) =>
      other is FollowSystem && other.light == light && other.dark == dark;

  @override
  int get hashCode => Object.hash(light, dark);
}
