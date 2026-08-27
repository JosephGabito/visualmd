import 'package:flutter/material.dart';

import '../../domain/reading/heading.dart';
import '../../domain/reading/table_of_contents.dart';
import '../theme/library_theme.dart';
import 'chrome_list_row.dart';
import 'panel_heading.dart';

/// The table of contents for the open document.
class OutlinePanel extends StatelessWidget {
  final TableOfContents tableOfContents;
  final String? activeAnchor;
  final ValueChanged<Heading> onSelect;

  const OutlinePanel({
    super.key,
    required this.tableOfContents,
    required this.activeAnchor,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final base = tableOfContents.baseLevel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PanelHeading('On this page'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(8, 2, 10, 24),
            children: [
              for (final heading in tableOfContents.headings)
                _OutlineEntry(
                  heading: heading,
                  depth: heading.level - base,
                  active: heading.anchor == activeAnchor,
                  onTap: () => onSelect(heading),
                ),
              if (tableOfContents.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: Text(
                    'No headings in this document.',
                    style: context.type.sans(color: p.muted, size: 12.5),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OutlineEntry extends StatelessWidget {
  final Heading heading;
  final int depth;
  final bool active;
  final VoidCallback onTap;

  const _OutlineEntry({
    required this.heading,
    required this.depth,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ChromeListRow(
      onTap: onTap,
      selected: active,
      showLocation: active,
      padding: EdgeInsets.fromLTRB(10.0 + depth * 14, 6, 8, 6),
      child: Text(
        heading.text.isEmpty ? '(untitled)' : heading.text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: context.chromeRow(
          color: active || depth == 0 ? p.ink : p.muted,
          weight: active ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
  }
}
