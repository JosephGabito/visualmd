// ignore_for_file: prefer_initializing_formals — private fields stay private; named params stay public.

import 'dart:convert';
import 'dart:io';

import '../../application/ports/markdown_scanner.dart';
import 'local_folder.dart';
import 'local_markdown.dart';
import 'scoped_access.dart';

/// Reads one directly offered markdown from the local filesystem.
final class LocalMarkdownScanner implements MarkdownScanner {
  final LocalMarkdownRegistry _registry;
  final ScopedAccess _access;

  const LocalMarkdownScanner(
    this._registry, {
    ScopedAccess access = const OpenAccess(),
  }) : _access = access;

  @override
  Future<ScannedMarkdown> scan(MarkdownRef ref) async {
    final markdown = _registry.lookup(ref);
    if (markdown == null) throw MarkdownUnavailable(ref);
    try {
      final content = await _access.within(
        markdown.bookmark,
        () async => utf8.decode(
          await File(markdown.path).readAsBytes(),
          allowMalformed: true,
        ),
      );
      return ScannedMarkdown(
        name: baseName(markdown.path),
        content: content,
        sourceId: localDocumentSourceId(markdown.path),
      );
    } on FileSystemException {
      throw MarkdownUnavailable(ref);
    }
  }
}
