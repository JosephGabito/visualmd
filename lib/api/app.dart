import 'package:flutter/material.dart';

import 'reader_controller.dart';
import '../presentation/code/code_highlighter.dart';
import 'screens/reader_screen.dart';
import '../presentation/theme/built_in_themes.dart';
import '../presentation/theme/reader_theme.dart';
import '../presentation/theme/theme_typefaces.dart';
import 'theme/library_theme.dart';
import '../presentation/theme/theme_choice.dart';

class VisualMdApp extends StatelessWidget {
  final ReaderController controller;
  final CodeHighlighter codeHighlighter;
  final void Function(String url) openExternal;
  final Future<void> Function()? openReaderSources;

  /// Lets the platform capture drops around the UI; identity when it doesn't need to.
  final Widget Function(Widget child) dropRegion;

  /// Top bar geometry: taller and inset where window controls share the row.
  final ({double height, double leadingInset}) topBar;

  /// Lets the platform make the top bar a window-drag handle; identity otherwise.
  final Widget Function(Widget child) windowDragRegion;

  /// Reveals the custom-theme directory; null where custom files are absent.
  final Future<void> Function()? openThemesFolder;

  const VisualMdApp({
    super.key,
    required this.controller,
    required this.codeHighlighter,
    required this.openExternal,
    this.openReaderSources,
    this.dropRegion = _identity,
    this.topBar = (height: 44, leadingInset: 8),
    this.windowDragRegion = _identity,
    this.openThemesFolder,
  });

  static Widget _identity(Widget child) => child;

  /// The theme for [brightness], with a launch-time reading face swapped in
  /// if one was named. The theme keeps its own colours either way.
  static ReaderTheme _wearing(
    ReaderController controller,
    Brightness brightness,
  ) {
    final theme = controller.themeFor(brightness);
    final serif = controller.serifOverride;
    if (serif == null) return theme;
    return ReaderTheme(
      id: theme.id,
      name: theme.name,
      brightness: theme.brightness,
      palette: theme.palette,
      typefaces: ThemeTypefaces(
        serif: serif,
        sans: theme.typefaces.sans,
        mono: theme.typefaces.mono,
      ),
      origin: theme.origin,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => MaterialApp(
        title: 'Visual MD',
        debugShowCheckedModeBanner: false,
        // A fixed theme wears the same clothes day and night; a pair follows the system.
        theme: libraryTheme(_wearing(controller, Brightness.light)),
        darkTheme: libraryTheme(_wearing(controller, Brightness.dark)),
        themeMode: switch (controller.themeChoice) {
          FollowSystem() => ThemeMode.system,
          FixedTheme(:final id) =>
            (controller.themes.byId(id) ?? BuiltInThemes.defaultLight).isDark
                ? ThemeMode.dark
                : ThemeMode.light,
        },
        home: dropRegion(
          ReaderScreen(
            controller: controller,
            codeHighlighter: codeHighlighter,
            openExternal: openExternal,
            openReaderSources: openReaderSources,
            topBar: topBar,
            windowDragRegion: windowDragRegion,
            openThemesFolder: openThemesFolder,
          ),
        ),
      ),
    );
  }
}
