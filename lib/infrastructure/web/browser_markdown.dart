import 'package:web/web.dart' as web;

import '../markdown_registry.dart';

sealed class BrowserMarkdown {
  String get name;
}

final class BrowserMarkdownFile implements BrowserMarkdown {
  final web.File file;

  const BrowserMarkdownFile(this.file);

  @override
  String get name => file.name;
}

final class BrowserMarkdownHandle implements BrowserMarkdown {
  final web.FileSystemFileHandle handle;

  const BrowserMarkdownHandle(this.handle);

  @override
  String get name => handle.name;
}

typedef BrowserMarkdownRegistry = MarkdownRegistry<BrowserMarkdown>;
