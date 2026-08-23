/// The appearance saved with a workspace.
sealed class WorkspaceTheme {
  const WorkspaceTheme();
}

/// One theme regardless of the operating system's brightness.
final class FixedWorkspaceTheme extends WorkspaceTheme {
  final String themeId;

  const FixedWorkspaceTheme(this.themeId) : assert(themeId != '');

  @override
  bool operator ==(Object other) =>
      other is FixedWorkspaceTheme && other.themeId == themeId;

  @override
  int get hashCode => themeId.hashCode;
}

/// A light/dark pair selected according to the operating system.
final class SystemWorkspaceTheme extends WorkspaceTheme {
  final String lightThemeId;
  final String darkThemeId;

  const SystemWorkspaceTheme({
    required this.lightThemeId,
    required this.darkThemeId,
  }) : assert(lightThemeId != ''),
       assert(darkThemeId != '');

  @override
  bool operator ==(Object other) =>
      other is SystemWorkspaceTheme &&
      other.lightThemeId == lightThemeId &&
      other.darkThemeId == darkThemeId;

  @override
  int get hashCode => Object.hash(lightThemeId, darkThemeId);
}
