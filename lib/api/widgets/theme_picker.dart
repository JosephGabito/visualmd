import 'package:flutter/material.dart';

import '../../presentation/theme/reader_theme.dart';
import '../../presentation/theme/reading_scale.dart';
import '../../presentation/theme/theme_choice.dart';
import '../../presentation/theme/theme_registry.dart';
import '../theme/library_theme.dart';
import 'anchored_menu.dart';

/// Pick what the reader wears: follow the system with the default pair, or
/// wear one theme all day. Each entry shows its own paper and ink.
class ThemePicker extends StatelessWidget {
  final ThemeRegistry registry;
  final ThemeChoice choice;
  final ValueChanged<ThemeChoice> onChoose;

  /// How paragraphs are told apart, and how to change it.
  final ParagraphMarking marking;
  final ValueChanged<ParagraphMarking> onMark;

  /// Where a reader may add their own themes; null where they cannot.
  final String? themesLocation;

  const ThemePicker({
    super.key,
    required this.registry,
    required this.choice,
    required this.onChoose,
    required this.marking,
    required this.onMark,
    this.themesLocation,
  });

  @override
  Widget build(BuildContext context) {
    final system = MediaQuery.platformBrightnessOf(context);
    final current = registry.resolve(choice, system);
    final following = choice is FollowSystem;

    return AnchoredMenu(
      tooltip: 'Reading: ${current.name}',
      width: 268,
      trigger: (context, isOpen) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: _Swatch(theme: current, size: 22),
      ),
      items: (context, close) {
        void pick(ThemeChoice next) {
          close();
          onChoose(next);
        }

        return [
          _Row(
            label: 'Follow system',
            leading: Icon(
              Icons.brightness_auto_outlined,
              size: 18,
              color: context.palette.muted,
            ),
            selected: following,
            onTap: () => pick(registry.systemPair),
          ),
          const _Rule(),
          const _SectionLabel('Light'),
          for (final theme in registry.light)
            _Row(
              label: theme.name,
              leading: _Swatch(theme: theme, size: 24),
              selected: !following && theme.id == current.id,
              onTap: () => pick(FixedTheme(theme.id)),
            ),
          const _SectionLabel('Dark'),
          for (final theme in registry.dark)
            _Row(
              label: theme.name,
              leading: _Swatch(theme: theme, size: 24),
              selected: !following && theme.id == current.id,
              onTap: () => pick(FixedTheme(theme.id)),
            ),
          const _Rule(),
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
            label: 'Indented, set solid',
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
          if (registry.errors.isNotEmpty) ...[
            const _Rule(),
            _Footnote(
              '${registry.errors.length} theme file skipped — see console',
            ),
          ] else if (themesLocation != null) ...[
            const _Rule(),
            _Footnote('Your own themes live in $themesLocation'),
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

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          decoration: BoxDecoration(
            color: _hovered
                ? p.accentSoft
                : (widget.selected
                      ? p.accentSoft.withValues(alpha: 0.55)
                      : null),
            borderRadius: BorderRadius.circular(8),
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
                    weight: widget.selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              if (widget.selected) Icon(Icons.check, size: 15, color: p.accent),
            ],
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
      child: Text(
        text.toUpperCase(),
        style: context.type
            .sans(
              color: context.palette.muted,
              size: 10.5,
              weight: FontWeight.w600,
            )
            .copyWith(letterSpacing: 1),
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    child: Divider(height: 1, thickness: 1, color: context.palette.border),
  );
}

class _Footnote extends StatelessWidget {
  final String text;
  const _Footnote(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 2, 14, 6),
    child: Text(
      text,
      style: context.type.sans(
        color: context.palette.muted,
        size: 11.5,
        height: 1.35,
      ),
    ),
  );
}

/// "Aa" on the theme's own paper, in its own ink, framed by its accent.
class _Swatch extends StatelessWidget {
  final ReaderTheme theme;
  final double size;

  const _Swatch({required this.theme, required this.size});

  @override
  Widget build(BuildContext context) {
    final t = theme.palette;
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
        style: context.type.serif(
          color: t.accent,
          size: size * 0.46,
          height: 1,
          weight: FontWeight.w600,
        ),
      ),
    );
  }
}
