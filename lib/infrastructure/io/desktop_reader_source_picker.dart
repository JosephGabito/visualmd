import 'package:flutter/services.dart';

import '../../application/ports/reader_source_picker.dart';
import '../../domain/library/markdown_file.dart';
import 'local_folder.dart';
import 'local_markdown.dart';

/// Registers the folders and Markdown files returned by macOS's unified Open
/// panel behind opaque application references.
final class DesktopReaderSourcePicker implements ReaderSourcePicker {
  static const _channel = MethodChannel(
    'com.visualmd.visualmd/reader-source-picker',
  );

  final LocalFolderRegistry _folders;
  final LocalMarkdownRegistry _markdowns;

  const DesktopReaderSourcePicker(this._folders, this._markdowns);

  @override
  Future<List<ReaderSourceSelection>> pick() async {
    final raw = await _channel.invokeListMethod<Object?>('pick');
    if (raw == null) return const [];

    final selected = <ReaderSourceSelection>[];
    for (final entry in raw) {
      if (entry is! Map<Object?, Object?>) continue;
      final kind = entry['kind'];
      final path = entry['path'];
      if (kind is! String || path is! String || path.isEmpty) continue;

      switch (kind) {
        case 'folder':
          final folder = LocalDirectory(path);
          selected.add(
            FolderSourceSelection(
              _folders.register(
                folder.name,
                folder,
                identity: localFolderIdentity(folder.path),
              ),
            ),
          );
        case 'markdown':
          final name = baseName(path);
          if (!MarkdownFile.isMarkdown(name)) continue;
          selected.add(
            MarkdownSourceSelection(
              _markdowns.register(
                name,
                LocalMarkdown(path),
                identity: localMarkdownIdentity(path),
              ),
            ),
          );
      }
    }
    return selected;
  }
}
