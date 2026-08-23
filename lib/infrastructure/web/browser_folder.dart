import 'package:web/web.dart' as web;

import '../folder_registry.dart';

/// A folder the browser handed us, in one of the two shapes browsers offer.
sealed class BrowserFolder {
  String get name;
}

/// A durable File System Access API handle, persisted through IndexedDB.
final class HandleDirectory implements BrowserFolder {
  final web.FileSystemDirectoryHandle handle;

  const HandleDirectory(this.handle);

  @override
  String get name => handle.name;
}

/// From a drag-and-drop: a directory entry we can walk lazily.
final class DroppedDirectory implements BrowserFolder {
  final web.FileSystemDirectoryEntry entry;
  const DroppedDirectory(this.entry);

  @override
  String get name => entry.name;
}

/// From a `<input webkitdirectory>` picker or a drop of loose files: every
/// file up front, each knowing its path relative to the picked folder.
final class PickedFiles implements BrowserFolder {
  @override
  final String name;

  /// (relative path, file) pairs; paths are `/`-separated and never start with `/`.
  final List<(String, web.File)> files;

  const PickedFiles({required this.name, required this.files});
}

typedef BrowserFolderRegistry = FolderRegistry<BrowserFolder>;
