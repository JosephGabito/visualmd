import 'library_root_id.dart';

/// Identity of a document: its top-level folder plus its path within it.
///
/// The path is always `/`-separated and never starts with `/`. Keeping the
/// root in the identity lets two folders safely contain the same relative
/// path, including the almost universal `README.md`.
final class DocumentId {
  final LibraryRootId rootId;
  final String path;

  DocumentId(this.rootId, String path) : path = _normalize(path) {
    if (this.path.isEmpty) {
      throw ArgumentError.value(path, 'path', 'must not be empty');
    }
  }

  static String _normalize(String raw) => raw
      .replaceAll('\\', '/')
      .split('/')
      .where((segment) => segment.isNotEmpty)
      .join('/');

  List<String> get segments => path.split('/');

  String get fileName => segments.last;

  /// Path of the containing folder, `''` for the library root.
  String get folderPath => segments.length == 1
      ? ''
      : segments.sublist(0, segments.length - 1).join('/');

  /// Resolves a link written relative to this document, the way a reader
  /// follows `../guide/intro.md` or `./notes.md` from the page they are on.
  /// Percent-encoding is decoded; a leading `/` means the library root.
  DocumentId resolve(String relativePath) {
    final decoded = Uri.decodeComponent(relativePath.replaceAll('\\', '/'));
    final stack = decoded.startsWith('/')
        ? <String>[]
        : (folderPath.isEmpty ? <String>[] : folderPath.split('/'));
    for (final segment in decoded.split('/')) {
      if (segment.isEmpty || segment == '.') continue;
      if (segment == '..') {
        if (stack.isNotEmpty) stack.removeLast();
      } else {
        stack.add(segment);
      }
    }
    return DocumentId(rootId, stack.join('/'));
  }

  @override
  bool operator ==(Object other) =>
      other is DocumentId && other.rootId == rootId && other.path == path;

  @override
  int get hashCode => Object.hash(rootId, path);

  @override
  String toString() => '$rootId:$path';
}
