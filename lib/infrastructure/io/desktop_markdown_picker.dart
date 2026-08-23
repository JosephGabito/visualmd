import 'package:file_selector/file_selector.dart';

import '../../application/ports/markdown_scanner.dart';
import '../../domain/library/markdown_file.dart';
import 'local_folder.dart';
import 'local_markdown.dart';

/// Native picker for one standalone Markdown source.
final class DesktopMarkdownPicker {
  final LocalMarkdownRegistry _registry;

  const DesktopMarkdownPicker(this._registry);

  Future<MarkdownRef?> pick() async {
    final selected = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Markdown',
          extensions: ['md', 'markdown', 'mdown', 'mkd'],
          uniformTypeIdentifiers: ['net.daringfireball.markdown'],
        ),
      ],
      confirmButtonText: 'Add Markdown',
    );
    if (selected == null || !MarkdownFile.isMarkdown(selected.name)) {
      return null;
    }
    final markdown = LocalMarkdown(selected.path);
    return _registry.register(
      baseName(selected.path),
      markdown,
      identity: localMarkdownIdentity(selected.path),
    );
  }
}
