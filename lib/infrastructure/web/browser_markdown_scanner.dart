import 'dart:js_interop';

import '../../application/ports/markdown_scanner.dart';
import 'browser_markdown.dart';
import 'browser_source_identity.dart';

/// Reads one directly offered browser file. Modern filesystem handles can be
/// compared for physical identity; legacy upload files cannot.
final class BrowserMarkdownScanner implements MarkdownScanner {
  final BrowserMarkdownRegistry _registry;
  final BrowserSourceIdentity _identities;

  const BrowserMarkdownScanner(this._registry, this._identities);

  @override
  Future<ScannedMarkdown> scan(MarkdownRef ref) async {
    final markdown = _registry.lookup(ref);
    if (markdown == null) throw MarkdownUnavailable(ref);
    final (file, sourceId) = switch (markdown) {
      BrowserMarkdownFile(:final file) => (file, null),
      BrowserMarkdownHandle(:final handle) => (
        await handle.getFile().toDart,
        await _identities.identify(handle),
      ),
    };
    return ScannedMarkdown(
      name: markdown.name,
      content: (await file.text().toDart).toDart,
      sourceId: sourceId,
    );
  }
}
