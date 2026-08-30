import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/library_chrome.dart';
import '../theme/library_theme.dart';

/// Visual MD's own reading surface for the licences registered by Flutter.
///
/// The stock Material page is designed as a generic diagnostic inventory. A
/// reader still deserves a readable measure, hierarchy, and an unambiguous way
/// home even when the prose is legal text.
final class LicensesScreen extends StatefulWidget {
  final ({double height, double leadingInset}) topBar;
  final Widget Function(Widget child) windowDragRegion;

  const LicensesScreen({
    super.key,
    required this.topBar,
    required this.windowDragRegion,
  });

  @override
  State<LicensesScreen> createState() => _LicensesScreenState();
}

final class _LicensesScreenState extends State<LicensesScreen> {
  late final Future<List<_PackageLicences>> _licences = _loadLicences();
  String? _selected;

  Future<List<_PackageLicences>> _loadLicences() async {
    final grouped = <String, List<List<LicenseParagraph>>>{};
    await for (final entry in LicenseRegistry.licenses) {
      final paragraphs = entry.paragraphs.toList();
      for (final package in entry.packages) {
        grouped.putIfAbsent(package, () => []).add(paragraphs);
      }
    }
    final result =
        grouped.entries
            .map((entry) => _PackageLicences(entry.key, entry.value))
            .toList(growable: false)
          ..sort(
            (left, right) =>
                left.name.toLowerCase().compareTo(right.name.toLowerCase()),
          );
    return result;
  }

  void _close() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {const SingleActivator(LogicalKeyboardKey.escape): _close},
    child: Focus(
      autofocus: true,
      child: Scaffold(
        backgroundColor: context.palette.paper,
        body: Column(
          children: [
            widget.windowDragRegion(
              SizedBox(
                width: double.infinity,
                child: _LicencesTopBar(
                  height: widget.topBar.height,
                  leadingInset: widget.topBar.leadingInset,
                  onClose: _close,
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<_PackageLicences>>(
                future: _licences,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final packages = snapshot.data!;
                  if (packages.isEmpty) {
                    return Center(
                      child: Text(
                        'No open-source licences are registered.',
                        style: context.chromeMetadata,
                      ),
                    );
                  }
                  final selected = packages.firstWhere(
                    (package) => package.name == _selected,
                    orElse: () => packages.first,
                  );
                  return LayoutBuilder(
                    builder: (context, constraints) =>
                        constraints.maxWidth < 760
                        ? _CompactLicences(
                            packages: packages,
                            selected: selected,
                            onSelected: (value) =>
                                setState(() => _selected = value),
                          )
                        : _WideLicences(
                            packages: packages,
                            selected: selected,
                            onSelected: (value) =>
                                setState(() => _selected = value),
                          ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

final class _LicencesTopBar extends StatelessWidget {
  final double height;
  final double leadingInset;
  final VoidCallback onClose;

  const _LicencesTopBar({
    required this.height,
    required this.leadingInset,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    // Reserve the same amount on both sides. The title then remains truly
    // centred without colliding with either macOS traffic lights or Close.
    final edgeWidth = leadingInset < 88 ? 88.0 : leadingInset;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: context.chrome.topBar,
        border: Border(bottom: BorderSide(color: context.chrome.separator)),
      ),
      child: Row(
        children: [
          SizedBox(width: edgeWidth),
          Expanded(
            child: Text(
              'Open-Source Licenses',
              textAlign: TextAlign.center,
              style: context.chromeRow(
                color: context.palette.ink,
                weight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(
            width: edgeWidth,
            child: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(
                  right: LibraryChromeScale.space4,
                ),
                child: TextButton(
                  onPressed: onClose,
                  child: const Text('Close'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final class _WideLicences extends StatelessWidget {
  final List<_PackageLicences> packages;
  final _PackageLicences selected;
  final ValueChanged<String> onSelected;

  const _WideLicences({
    required this.packages,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(
        width: 280,
        child: _PackageIndex(
          packages: packages,
          selected: selected,
          onSelected: onSelected,
        ),
      ),
      VerticalDivider(width: 1, color: context.chrome.separator),
      Expanded(child: _LicenceReader(package: selected)),
    ],
  );
}

final class _CompactLicences extends StatelessWidget {
  final List<_PackageLicences> packages;
  final _PackageLicences selected;
  final ValueChanged<String> onSelected;

  const _CompactLicences({
    required this.packages,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        color: context.chrome.panel,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: selected.name,
            isExpanded: true,
            items: packages
                .map(
                  (package) => DropdownMenuItem(
                    value: package.name,
                    child: Text(package.name),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value != null) onSelected(value);
            },
          ),
        ),
      ),
      Expanded(child: _LicenceReader(package: selected)),
    ],
  );
}

final class _PackageIndex extends StatelessWidget {
  final List<_PackageLicences> packages;
  final _PackageLicences selected;
  final ValueChanged<String> onSelected;

  const _PackageIndex({
    required this.packages,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: context.chrome.panel,
    child: ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      itemCount: packages.length,
      itemBuilder: (context, index) {
        final package = packages[index];
        final active = package.name == selected.name;
        return Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: ListTile(
            selected: active,
            selectedTileColor: context.chrome.selected,
            hoverColor: context.chrome.hover,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(LibraryChromeScale.rowRadius),
            ),
            dense: true,
            title: Text(
              package.name,
              style: context.chromeRow(color: context.palette.ink),
            ),
            subtitle: Text(
              '${package.entries.length} ${package.entries.length == 1 ? 'license' : 'licenses'}',
              style: context.chromeMetadata,
            ),
            onTap: () => onSelected(package.name),
          ),
        );
      },
    ),
  );
}

final class _LicenceReader extends StatelessWidget {
  final _PackageLicences package;

  const _LicenceReader({required this.package});

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.palette.paper,
    child: ListView(
      key: ValueKey(package.name),
      padding: const EdgeInsets.fromLTRB(40, 42, 40, 64),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  package.name,
                  style: context.type.serif(
                    color: context.palette.ink,
                    size: 28,
                    height: 1.15,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${package.entries.length} open-source ${package.entries.length == 1 ? 'license' : 'licenses'}',
                  style: context.chromeMetadata,
                ),
                const SizedBox(height: 28),
                for (
                  var entryIndex = 0;
                  entryIndex < package.entries.length;
                  entryIndex++
                ) ...[
                  if (entryIndex > 0) ...[
                    const SizedBox(height: 28),
                    Divider(color: context.chrome.separator),
                    const SizedBox(height: 28),
                  ],
                  for (final paragraph in package.entries[entryIndex])
                    _LicenceParagraph(paragraph: paragraph),
                ],
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

final class _LicenceParagraph extends StatelessWidget {
  final LicenseParagraph paragraph;

  const _LicenceParagraph({required this.paragraph});

  @override
  Widget build(BuildContext context) {
    final centred = paragraph.indent == LicenseParagraph.centeredIndent;
    return Padding(
      padding: EdgeInsets.only(
        left: centred ? 0 : paragraph.indent * 18.0,
        bottom: 14,
      ),
      child: SelectableText(
        paragraph.text,
        textAlign: centred ? TextAlign.center : TextAlign.start,
        style: context.type.sans(
          color: context.palette.ink,
          size: 13.5,
          height: 1.55,
        ),
      ),
    );
  }
}

final class _PackageLicences {
  final String name;
  final List<List<LicenseParagraph>> entries;

  const _PackageLicences(this.name, this.entries);
}
