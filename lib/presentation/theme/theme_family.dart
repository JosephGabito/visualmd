import 'dart:ui' show Brightness;

import 'theme_choice.dart';

/// One named appearance with a light member, a dark member, or both.
///
/// A paired family follows the operating system after it is chosen. A family
/// with only one member stays fixed, because inventing its missing half would
/// no longer be that theme.
final class ThemeFamily {
  final String name;
  final String? light;
  final String? dark;

  const ThemeFamily({required this.name, this.light, this.dark})
    : assert(light != null || dark != null);

  bool supports(Brightness brightness) => idFor(brightness) != null;

  String? idFor(Brightness brightness) => switch (brightness) {
    Brightness.light => light,
    Brightness.dark => dark,
  };

  ThemeChoice choiceFor(Brightness brightness) {
    final lightId = light;
    final darkId = dark;
    if (lightId != null && darkId != null) {
      return FollowSystem(light: lightId, dark: darkId);
    }
    return FixedTheme(idFor(brightness)!);
  }

  bool selects(ThemeChoice choice, Brightness brightness) {
    final familyChoice = choiceFor(brightness);
    if (choice == familyChoice) return true;
    if (choice is FixedTheme) {
      return choice.id == idFor(brightness);
    }
    return false;
  }

  Iterable<String> get themeIds => [light, dark].nonNulls;
}
