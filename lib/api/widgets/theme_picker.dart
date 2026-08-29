import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../presentation/theme/built_in_themes.dart';
import '../../presentation/theme/reader_theme.dart';
import '../../presentation/theme/reading_mode.dart';
import '../../presentation/theme/reading_scale.dart';
import '../../presentation/theme/theme_choice.dart';
import '../../presentation/theme/theme_registry.dart';
import '../theme/library_theme.dart';
import '../theme/library_chrome.dart';
import 'anchored_menu.dart';

/// Pick what the reader wears: the default pair, a named light/dark family, or
/// one fixed theme. Each entry shows its own paper and ink.
class ThemePicker extends StatelessWidget {
  final AnchoredMenuController? menuController;
  final ThemeRegistry registry;
  final ThemeChoice choice;
  final ValueChanged<ThemeChoice> onChoose;

  /// Which proportional voice sets the document, and how to change it.
  final ReadingMode mode;
  final ValueChanged<ReadingMode> onMode;

  /// How paragraphs are told apart, and how to change it.
  final ParagraphMarking marking;
  final ValueChanged<ParagraphMarking> onMark;

  /// Reveals the custom-theme directory; null where custom files are absent.
  final Future<void> Function()? onOpenThemesFolder;

  const ThemePicker({
    super.key,
    required this.registry,
    required this.choice,
    required this.onChoose,
    required this.mode,
    required this.onMode,
    required this.marking,
    required this.onMark,
    this.onOpenThemesFolder,
    this.menuController,
  });

  @override
  Widget build(BuildContext context) {
    final system = MediaQuery.platformBrightnessOf(context);
    final current = registry.resolve(choice, system);
    final followingDefault = choice == registry.systemPair;
    final featuredIds = {BuiltInThemes.paper.id, BuiltInThemes.lamplight.id};
    final individualLight = registry.light.where(
      (theme) => !featuredIds.contains(theme.id),
    );
    final individualDark = registry.dark.where(
      (theme) => !featuredIds.contains(theme.id),
    );

    return AnchoredMenu(
      controller: menuController,
      tooltip: 'Appearance: ${current.name}, ${mode.label}',
      width: 268,
      trigger: (context, isOpen) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: _Swatch(theme: current, mode: mode, size: 22),
      ),
      items: (context, close) {
        void pick(ThemeChoice next) {
          close();
          onChoose(next);
        }

        void readIn(ReadingMode next) {
          close();
          onMode(next);
        }

        return [
          const _SectionLabel('Reading mode'),
          for (final candidate in ReadingMode.values)
            _Row(
              label: candidate.label,
              leading: _ReadingModeSample(mode: candidate),
              selected: mode == candidate,
              onTap: () => readIn(candidate),
            ),
          const _SectionLabel('Paragraphs'),
          _Row(
            label: 'Separated by space',
            leading: Icon(
              Icons.notes_outlined,
              size: 18,
              color: context.palette.muted,
            ),
            selected: marking == ParagraphMarking.spaced,
            onTap: () {
              close();
              onMark(ParagraphMarking.spaced);
            },
          ),
          _Row(
            label: 'Book-style indents',
            leading: Icon(
              Icons.format_indent_increase,
              size: 18,
              color: context.palette.muted,
            ),
            selected: marking == ParagraphMarking.indented,
            onTap: () {
              close();
              onMark(ParagraphMarking.indented);
            },
          ),
          const _Rule(),
          const _SectionLabel('Themes'),
          _Row(
            label: 'Follow system',
            leading: Icon(
              Icons.brightness_auto_outlined,
              size: 18,
              color: context.palette.muted,
            ),
            selected: followingDefault,
            onTap: () => pick(registry.systemPair),
          ),
          for (final theme in [BuiltInThemes.paper, BuiltInThemes.lamplight])
            _Row(
              label: theme.name,
              leading: _Swatch(theme: theme, mode: mode, size: 24),
              selected: choice is FixedTheme && theme.id == current.id,
              onTap: () => pick(FixedTheme(theme.id)),
            ),
          const _SectionLabel('More themes'),
          for (final family in BuiltInThemes.families)
            if (family.supports(system))
              _Row(
                label: family.followsSystem
                    ? '${family.name} · follows system'
                    : family.name,
                leading: _Swatch(
                  theme: registry.byId(family.idFor(system)!)!,
                  mode: mode,
                  size: 24,
                ),
                selected: family.selects(choice, system),
                onTap: () => pick(family.choiceFor(system)),
              ),
          const _SectionLabel('Light'),
          for (final theme in individualLight)
            _Row(
              label: theme.name,
              leading: _Swatch(theme: theme, mode: mode, size: 24),
              selected: choice is FixedTheme && theme.id == current.id,
              onTap: () => pick(FixedTheme(theme.id)),
            ),
          const _SectionLabel('Dark'),
          for (final theme in individualDark)
            _Row(
              label: theme.name,
              leading: _Swatch(theme: theme, mode: mode, size: 24),
              selected: choice is FixedTheme && theme.id == current.id,
              onTap: () => pick(FixedTheme(theme.id)),
            ),
          if (registry.errors.isNotEmpty) ...[
            const _Rule(),
            _SectionLabel(
              registry.errors.length == 1 ? 'Skipped theme' : 'Skipped themes',
            ),
            for (final error in registry.errors) _ThemeError(error),
          ],
          if (onOpenThemesFolder != null) ...[
            const _Rule(),
            _Row(
              label: 'Open themes folder',
              leading: Icon(
                Icons.folder_open_outlined,
                size: 18,
                color: context.palette.muted,
              ),
              selected: false,
              onTap: () {
                close();
                onOpenThemesFolder!();
              },
            ),
          ],
        ];
      },
    );
  }
}

/// A row that lights up under the pointer, so the menu answers before it acts.
class _Row extends StatefulWidget {
  final String label;
  final Widget leading;
  final bool selected;
  final VoidCallback onTap;

  const _Row({
    required this.label,
    required this.leading,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  var _hovered = false;
  var _focused = false;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final chrome = context.chrome;
    final still = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      container: true,
      button: true,
      enabled: true,
      focusable: true,
      focused: _focused,
      selected: widget.selected,
      label: widget.label,
      excludeSemantics: true,
      onTap: widget.onTap,
      child: FocusableActionDetector(
        includeFocusSemantics: false,
        mouseCursor: SystemMouseCursors.click,
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap();
              return null;
            },
          ),
        },
        onShowHoverHighlight: (value) => setState(() => _hovered = value),
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: still ? Duration.zero : const Duration(milliseconds: 110),
            curve: Curves.easeOut,
            constraints: const BoxConstraints(minHeight: 36),
            margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: _hovered || _focused
                  ? (widget.selected ? chrome.selectedHover : chrome.hover)
                  : (widget.selected ? chrome.selected : null),
              borderRadius: BorderRadius.circular(
                LibraryChromeScale.controlRadius,
              ),
            ),
            child: Row(
              children: [
                widget.leading,
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    widget.label,
                    overflow: TextOverflow.ellipsis,
                    style: context.type.sans(
                      color: widget.selected ? p.accent : p.ink,
                      weight: widget.selected
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
                if (widget.selected)
                  Icon(Icons.check, size: 15, color: p.accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      child: Text(text.toUpperCase(), style: context.chromeSectionLabel),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    child: Divider(height: 1, thickness: 1, color: context.chrome.separator),
  );
}

/// A small specimen in the active theme, so the choice can be judged before
/// the menu closes and the document redraws.
class _ReadingModeSample extends StatelessWidget {
  final ReadingMode mode;

  const _ReadingModeSample({required this.mode});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 18,
    height: 18,
    child: Center(
      child: Text(
        'Aa',
        style: context.type.reading(
          mode,
          color: context.palette.muted,
          size: 11,
          height: 1,
          weight: FontWeight.w600,
        ),
      ),
    ),
  );
}

class _ThemeError extends StatelessWidget {
  final ThemeLoadError error;
  const _ThemeError(this.error);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 3, 14, 7),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${error.origin} skipped',
          style: context.type.sans(
            color: context.palette.ink,
            size: 11.5,
            weight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          error.reason,
          style: context.type.sans(
            color: context.palette.muted,
            size: 11.5,
            height: 1.35,
          ),
        ),
      ],
    ),
  );
}

/// "Aa" on the theme's own paper, in its own ink, framed by its accent.
class _Swatch extends StatelessWidget {
  final ReaderTheme theme;
  final ReadingMode mode;
  final double size;

  const _Swatch({required this.theme, required this.mode, required this.size});

  @override
  Widget build(BuildContext context) {
    final t = theme.palette;
    final type = LibraryTypefaces(theme.typefaces);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: t.paper,
        borderRadius: BorderRadius.circular(size * 0.25),
        border: Border.all(color: t.border),
      ),
      child: Text(
        'Aa',
        style: type.reading(
          mode,
          color: t.accent,
          size: size * 0.46,
          height: 1,
          weight: FontWeight.w600,
        ),
      ),
    );
  }
}
