/// What the library recognises as a markdown file.
abstract final class MarkdownFile {
  static const extensions = {'.md', '.markdown', '.mdown', '.mkd'};

  static bool isMarkdown(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot < 0) return false;
    return extensions.contains(fileName.substring(dot).toLowerCase());
  }

  static String stripExtension(String fileName) {
    final dot = fileName.lastIndexOf('.');
    return dot <= 0 ? fileName : fileName.substring(0, dot);
  }
}
