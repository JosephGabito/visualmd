import 'package:flutter/material.dart';

import '../theme/library_chrome.dart';
import '../theme/library_theme.dart';
import 'brand_mark.dart';

/// Shown while a folder or markdown is dragged across the window.
class DropOverlay extends StatelessWidget {
  const DropOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return IgnorePointer(
      child: Container(
        color: p.paper.withValues(alpha: 0.88),
        padding: const EdgeInsets.all(24),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(
              LibraryChromeScale.windowRadius,
            ),
            border: Border.all(color: p.accent, width: 2),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const BrandMark(size: 64),
                const SizedBox(height: 18),
                Text(
                  'Drop to open',
                  style: context.type.serif(
                    color: p.ink,
                    size: 30,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Open one markdown or a whole folder.',
                  style: context.type.sans(color: p.muted, size: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
