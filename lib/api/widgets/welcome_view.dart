import 'package:flutter/material.dart';

import '../theme/library_theme.dart';
import 'brand_mark.dart';

/// The front door: nothing open yet.
class WelcomeView extends StatelessWidget {
  final bool opening;
  final String? error;
  final VoidCallback onOpenFolder;
  final VoidCallback onOpenSample;

  const WelcomeView({
    super.key,
    required this.opening,
    required this.error,
    required this.onOpenFolder,
    required this.onOpenSample,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
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
                constraints: const BoxConstraints(maxWidth: 520),
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
                      'The last markdown reader you need.',
                      textAlign: TextAlign.center,
                      style: context.type.serif(
                        color: p.muted,
                        size: 19,
                        style: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 40),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 44,
                        horizontal: 24,
                      ),
                      decoration: BoxDecoration(
                        color: p.panel.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: p.border, width: 1.5),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.drive_folder_upload_outlined,
                            size: 30,
                            color: p.muted,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            opening
                                ? 'Shelving your documents…'
                                : 'Drop a folder or markdown anywhere',
                            style: context.type.sans(
                              color: p.ink,
                              size: 15,
                              weight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Open one file, or every markdown nested in a folder.',
                            textAlign: TextAlign.center,
                            style: context.type.sans(color: p.muted, size: 13),
                          ),
                          const SizedBox(height: 22),
                          FilledButton.icon(
                            onPressed: opening ? null : onOpenFolder,
                            style: FilledButton.styleFrom(
                              backgroundColor: p.accent,
                              foregroundColor: p.paper,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 14,
                              ),
                              textStyle: context.type.sans(
                                color: p.paper,
                                size: 14,
                                weight: FontWeight.w600,
                              ),
                            ),
                            icon: const Icon(
                              Icons.folder_open_outlined,
                              size: 18,
                            ),
                            label: const Text('Open a folder'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextButton(
                      onPressed: opening ? null : onOpenSample,
                      child: Text(
                        'or browse the sample library',
                        style: context.type.sans(
                          color: p.accent,
                          size: 13.5,
                          weight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        error!,
                        style: context.type.sans(color: p.accent, size: 13),
                      ),
                    ],
                    const SizedBox(height: 28),
                    Text(
                      'Nothing leaves your machine.',
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
