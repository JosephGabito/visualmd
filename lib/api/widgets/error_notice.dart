import 'package:flutter/material.dart';

import '../theme/library_chrome.dart';
import '../theme/library_theme.dart';

/// A persistent, dismissible failure notice for an occupied reader.
final class ErrorNotice extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;
  final VoidCallback? onRetry;

  const ErrorNotice({
    super.key,
    required this.message,
    required this.onDismiss,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      container: true,
      liveRegion: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Material(
          color: Colors.transparent,
          child: Container(
            key: const ValueKey('reader-error-notice'),
            decoration: BoxDecoration(
              color: p.panel,
              borderRadius: BorderRadius.circular(
                LibraryChromeScale.componentRadius,
              ),
              border: Border.all(color: p.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: 0,
                  child: ColoredBox(
                    color: p.accent,
                    child: const SizedBox(width: 2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          message,
                          style: context.type.sans(color: p.ink, size: 13),
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (onRetry != null) ...[
                        TextButton(
                          onPressed: onRetry,
                          child: const Text('Retry'),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Tooltip(
                        message: 'Dismiss',
                        child: IconButton(
                          onPressed: onDismiss,
                          icon: Icon(Icons.close, size: 17, color: p.muted),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                            width: 28,
                            height: 28,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
