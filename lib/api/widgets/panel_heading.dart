import 'package:flutter/material.dart';

import '../theme/library_theme.dart';

/// Small-caps label atop a side panel.
class PanelHeading extends StatelessWidget {
  final String text;
  final Widget? trailing;

  const PanelHeading(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 10, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text.toUpperCase(),
              overflow: TextOverflow.ellipsis,
              style: context.type
                  .sans(color: p.muted, size: 11, weight: FontWeight.w600)
                  .copyWith(letterSpacing: 1.1),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
