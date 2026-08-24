import 'package:flutter/material.dart';

import '../theme/library_theme.dart';
import 'brand_mark.dart';

/// The front door: nothing open yet.
class WelcomeView extends StatelessWidget {
  final bool opening;
  final String? error;
  final VoidCallback onOpen;
  final VoidCallback onOpenWorkspace;
  final VoidCallback onOpenSample;

  /// Whether Open can choose either a Markdown file or a folder in one action.
  final bool opensMixedSources;

  const WelcomeView({
    super.key,
    required this.opening,
    required this.error,
    required this.onOpen,
    required this.onOpenWorkspace,
    required this.onOpenSample,
    required this.opensMixedSources,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final shortcuts = _ShortcutLabels.forPlatform(Theme.of(context).platform);
    return LayoutBuilder(
      builder: (context, constraints) {
        const verticalInset = 24.0;
        final minimumHeight = constraints.hasBoundedHeight
            ? (constraints.maxHeight - verticalInset * 2).clamp(
                0.0,
                double.infinity,
              )
            : 0.0;
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: verticalInset),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minimumHeight),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const BrandMark(size: 64),
                    const SizedBox(height: 22),
                    Text(
                      'Visual MD',
                      style: context.type.serif(
                        color: p.ink,
                        size: 40,
                        weight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'A quiet place to read Markdown.',
                      textAlign: TextAlign.center,
                      style: context.type.serif(color: p.muted, size: 18),
                    ),
                    const SizedBox(height: 34),
                    Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: p.border),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _LaunchAction(
                            icon: Icons.folder_open_outlined,
                            title: 'Open…',
                            description: opensMixedSources
                                ? 'Open a Markdown file or folder'
                                : 'Open a folder of Markdown files',
                            shortcut: shortcuts.open,
                            onPressed: opening ? null : onOpen,
                          ),
                          const _ActionDivider(),
                          _LaunchAction(
                            icon: Icons.grid_view_outlined,
                            title: 'Open Workspace…',
                            description: 'Restore a saved workspace',
                            shortcut: shortcuts.workspace,
                            onPressed: opening ? null : onOpenWorkspace,
                          ),
                          const _ActionDivider(),
                          _LaunchAction(
                            icon: Icons.menu_book_outlined,
                            title: 'Open Sample Library',
                            description: 'Explore a ready-made library',
                            shortcut: shortcuts.sample,
                            onPressed: opening ? null : onOpenSample,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (opening)
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.8,
                              color: p.muted,
                            ),
                          )
                        else
                          Icon(
                            Icons.drive_folder_upload_outlined,
                            size: 18,
                            color: p.muted,
                          ),
                        const SizedBox(width: 9),
                        Flexible(
                          child: Text(
                            opening
                                ? 'Shelving your documents…'
                                : 'Or drop Markdown files or folders anywhere',
                            textAlign: TextAlign.center,
                            style: context.type.sans(color: p.muted, size: 13),
                          ),
                        ),
                      ],
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        error!,
                        textAlign: TextAlign.center,
                        style: context.type.sans(color: p.accent, size: 13),
                      ),
                    ],
                    const SizedBox(height: 26),
                    Text(
                      'Your files stay on your device.',
                      style: context.type.sans(color: p.muted, size: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LaunchAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String shortcut;
  final VoidCallback? onPressed;

  const _LaunchAction({
    required this.icon,
    required this.title,
    required this.description,
    required this.shortcut,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        hoverColor: p.accent.withValues(alpha: 0.07),
        focusColor: p.accent.withValues(alpha: 0.09),
        highlightColor: p.accent.withValues(alpha: 0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Icon(icon, size: 21, color: p.muted),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: context.type.sans(
                        color: p.ink,
                        size: 14.5,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: context.type.sans(color: p.muted, size: 12.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Text(
                shortcut,
                style: context.type.sans(
                  color: p.muted,
                  size: 12,
                  weight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionDivider extends StatelessWidget {
  const _ActionDivider();

  @override
  Widget build(BuildContext context) => Divider(
    height: 1,
    thickness: 1,
    indent: 54,
    color: context.palette.border,
  );
}

final class _ShortcutLabels {
  final String open;
  final String workspace;
  final String sample;

  const _ShortcutLabels({
    required this.open,
    required this.workspace,
    required this.sample,
  });

  factory _ShortcutLabels.forPlatform(TargetPlatform platform) =>
      platform == TargetPlatform.macOS
      ? const _ShortcutLabels(open: '⌘O', workspace: '⇧⌘O', sample: '⌥⌘O')
      : const _ShortcutLabels(
          open: 'Ctrl+O',
          workspace: 'Ctrl+Shift+O',
          sample: 'Ctrl+Alt+O',
        );
}
