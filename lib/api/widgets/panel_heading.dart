import 'package:flutter/material.dart';

import '../theme/library_chrome.dart';
import '../theme/library_theme.dart';

/// Small-caps label atop a side panel.
class PanelHeading extends StatelessWidget {
  final String text;
  final Widget? trailing;

  const PanelHeading(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        LibraryChromeScale.space4,
        LibraryChromeScale.space4,
        LibraryChromeScale.space2,
        LibraryChromeScale.space2,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text.toUpperCase(),
              overflow: TextOverflow.ellipsis,
              style: context.chromeSectionLabel,
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
