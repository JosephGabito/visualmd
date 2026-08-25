import 'document.dart';
import 'document_id.dart';
import 'document_source_id.dart';
import 'folder.dart';
import 'hidden_folders.dart';
import 'library_root.dart';
import 'library_root_id.dart';
import 'markdown_file.dart';
import 'natural_order.dart';

/// A file as it arrives from whatever scanned the folder.
///
/// Production adapters provide path, identity, and an indexed title. [content]
/// exists for bundled/in-memory sources, while [title] lets an adapter retain
/// what it learned without retaining the complete document source.
final class FileEntry {
  final String path;
  final String? content;
  final DocumentSourceId? sourceId;
  final String? title;

  const FileEntry(this.path, this.content, {this.sourceId, this.title});
}

/// Turns one flat scan into a [LibraryRoot]: keeps only markdown outside
/// hidden folders, drops folders with nothing to read, and shelves everything
/// in natural order with READMEs first.
abstract final class LibraryBuilder {
  static LibraryRoot buildRoot({
    required LibraryRootId id,
    required String name,
    required Iterable<FileEntry> files,
  }) {
    final root = _Node(name: name, path: '');
    final seen = <DocumentId>{};

    for (final file in files) {
      if (!MarkdownFile.isMarkdown(file.path)) continue;
      if (HiddenFolders.hidesPath(file.path)) continue;
      final documentId = DocumentId(id, file.path);
      if (!seen.add(documentId)) continue;

      var node = root;
      for (final segment in documentId.segments.sublist(
        0,
        documentId.segments.length - 1,
      )) {
        node = node.children.putIfAbsent(
          segment,
          () => _Node(
            name: segment,
            path: node.path.isEmpty ? segment : '${node.path}/$segment',
          ),
        );
      }
      node.documents.add(
        Document(
          id: documentId,
          content: file.content,
          sourceId: file.sourceId,
          title: file.title,
        ),
      );
    }

    return LibraryRoot(id: id, name: name, folder: root.toFolder());
  }
}

final class _Node {
  final String name;
  final String path;
  final Map<String, _Node> children = {};
  final List<Document> documents = [];

  _Node({required this.name, required this.path});

  Folder toFolder() {
    final folders =
        children.values
            .map((child) => child.toFolder())
            .where((folder) => folder.documentCount > 0)
            .toList()
          ..sort((a, b) => NaturalOrder.compare(a.name, b.name));

    final docs = [...documents]
      ..sort((a, b) {
        if (a.isReadme != b.isReadme) return a.isReadme ? -1 : 1;
        return NaturalOrder.compare(a.fileName, b.fileName);
      });

    return Folder(name: name, path: path, folders: folders, documents: docs);
  }
}
