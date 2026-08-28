import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/library/library.dart';
import '../../domain/search/search_result.dart';
import '../theme/library_chrome.dart';
import '../theme/library_theme.dart';

final class DocumentFindBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onClose;
  final int active;
  final int total;
  final bool searching;

  const DocumentFindBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onNext,
    required this.onPrevious,
    required this.onClose,
    required this.active,
    required this.total,
    required this.searching,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final chrome = context.chrome;
    return Material(
      elevation: 0,
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(LibraryChromeScale.floatingRadius),
      child: Container(
        width: 390,
        height: 42,
        padding: const EdgeInsets.only(left: 10, right: 4),
        decoration: BoxDecoration(
          // Paint the opaque material after its shadows. A transparent
          // decoration would let the filled shadow darken the entire control
          // instead of describing elevation around its edge.
          color: chrome.elevated,
          borderRadius: BorderRadius.circular(
            LibraryChromeScale.floatingRadius,
          ),
          boxShadow: [
            BoxShadow(
              color: chrome.shadow,
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: chrome.shadow.withValues(alpha: 0.45),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.search, size: 17, color: p.muted),
            const SizedBox(width: 7),
            Expanded(
              child: _SearchField(
                key: const ValueKey('document-search-field'),
                controller: controller,
                focusNode: focusNode,
                hint: 'Find in this document',
                onChanged: onChanged,
                onNext: onNext,
                onPrevious: onPrevious,
                onClose: onClose,
              ),
            ),
            if (searching)
              const SizedBox.square(
                dimension: 14,
                child: CircularProgressIndicator(strokeWidth: 1.5),
              )
            else
              Text(
                controller.text.isEmpty
                    ? ''
                    : total == 0
                    ? '0 of 0'
                    : '${active + 1} of $total',
                style: context.type.sans(color: p.muted, size: 11.5),
              ),
            _SearchButton(
              tooltip: 'Previous match  (⇧↩)',
              icon: Icons.keyboard_arrow_up,
              onPressed: total == 0 ? null : onPrevious,
            ),
            _SearchButton(
              tooltip: 'Next match  (↩)',
              icon: Icons.keyboard_arrow_down,
              onPressed: total == 0 ? null : onNext,
            ),
            _SearchButton(
              tooltip: 'Close  (Esc)',
              icon: Icons.close,
              onPressed: onClose,
            ),
          ],
        ),
      ),
    );
  }
}

final class LibrarySearchPanel extends StatelessWidget {
  final Library library;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;
  final List<DocumentSearchResult> results;
  final bool searching;
  final void Function(DocumentSearchResult result, int match) onSelect;

  const LibrarySearchPanel({
    super.key,
    required this.library,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClose,
    required this.results,
    required this.searching,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final total = results.fold<int>(
      0,
      (sum, result) => sum + result.matches.length,
    );
    final rows =
        <
          ({
            DocumentSearchResult result,
            int match,
            bool firstDocument,
            bool firstRoot,
          })
        >[
          for (var resultIndex = 0; resultIndex < results.length; resultIndex++)
            for (
              var match = 0;
              match < results[resultIndex].matches.length;
              match++
            )
              (
                result: results[resultIndex],
                match: match,
                firstDocument: match == 0,
                firstRoot:
                    match == 0 &&
                    (resultIndex == 0 ||
                        results[resultIndex - 1].document.id.rootId !=
                            results[resultIndex].document.id.rootId),
              ),
        ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Search library',
                  style: context.type.sans(
                    color: p.ink,
                    size: 12,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
              _SearchButton(
                tooltip: 'Close search  (Esc)',
                icon: Icons.close,
                onPressed: onClose,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 9),
            decoration: BoxDecoration(
              color: p.paper,
              border: Border.all(color: p.border),
              borderRadius: BorderRadius.circular(
                LibraryChromeScale.controlRadius,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.search, size: 16, color: p.muted),
                const SizedBox(width: 7),
                Expanded(
                  child: _SearchField(
                    key: const ValueKey('library-search-field'),
                    controller: controller,
                    focusNode: focusNode,
                    hint: 'Find across every document',
                    onChanged: onChanged,
                    onClose: onClose,
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
          child: Text(
            controller.text.isEmpty
                ? 'Type to search every folder'
                : searching
                ? 'Searching…'
                : '$total ${total == 1 ? 'match' : 'matches'} in ${results.length} ${results.length == 1 ? 'document' : 'documents'}',
            style: context.type.sans(color: p.muted, size: 11.5),
          ),
        ),
        Expanded(
          child: controller.text.isNotEmpty && !searching && rows.isEmpty
              ? Center(
                  child: Text(
                    'No matches',
                    style: context.type.sans(color: p.muted, size: 12.5),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (row.firstRoot)
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              8,
                              index == 0 ? 5 : 16,
                              8,
                              5,
                            ),
                            child: Text(
                              library
                                      .rootById(row.result.document.id.rootId)
                                      ?.name ??
                                  'Folder',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.type.sans(
                                color: p.muted,
                                size: 11,
                                weight: FontWeight.w600,
                              ),
                            ),
                          ),
                        if (row.firstDocument)
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              8,
                              row.firstRoot ? 2 : 12,
                              8,
                              4,
                            ),
                            child: Text(
                              row.result.document.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.type.sans(
                                color: p.ink,
                                size: 12,
                                weight: FontWeight.w600,
                              ),
                            ),
                          ),
                        _SearchResultRow(
                          path: row.result.document.id.path,
                          excerpt: row.result.matches[row.match].excerpt,
                          onTap: () => onSelect(row.result, row.match),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }
}

final class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;
  final VoidCallback onClose;

  const _SearchField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.onChanged,
    this.onNext,
    this.onPrevious,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.escape): onClose,
      const SingleActivator(LogicalKeyboardKey.enter): ?onNext,
      const SingleActivator(LogicalKeyboardKey.enter, shift: true): ?onPrevious,
    },
    child: TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      style: context.type.sans(color: context.palette.ink, size: 13),
      decoration: InputDecoration(
        isDense: true,
        border: InputBorder.none,
        hintText: hint,
        hintStyle: context.type.sans(color: context.palette.muted, size: 13),
        contentPadding: EdgeInsets.zero,
      ),
    ),
  );
}

final class _SearchResultRow extends StatelessWidget {
  final String path;
  final String excerpt;
  final VoidCallback onTap;

  const _SearchResultRow({
    required this.path,
    required this.excerpt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final chrome = context.chrome;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(LibraryChromeScale.rowRadius),
      hoverColor: chrome.hover,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              excerpt,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.type.sans(color: p.ink, size: 12.5, height: 1.35),
            ),
            const SizedBox(height: 2),
            Text(
              path,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.type.sans(color: p.muted, size: 10.5),
            ),
          ],
        ),
      ),
    );
  }
}

final class _SearchButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  const _SearchButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    icon: Icon(icon, size: 17),
    visualDensity: VisualDensity.compact,
    padding: const EdgeInsets.all(5),
    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
  );
}
