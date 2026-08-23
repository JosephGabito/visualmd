import 'dart:typed_data';

import '../folder_registry.dart';

/// A folder on the local filesystem, as the desktop handed it to us.
sealed class LocalFolder {
  String get name;
}

/// A directory path. [bookmark] is a macOS security-scoped bookmark when the
/// sandbox needs one to read outside the container (drops from Finder).
final class LocalDirectory implements LocalFolder {
  final String path;
  final Uint8List? bookmark;

  const LocalDirectory(this.path, {this.bookmark});

  @override
  String get name => _baseName(path);
}

/// Loose files dropped together, each with its own optional bookmark.
final class LocalFiles implements LocalFolder {
  @override
  final String name;
  final List<(String, Uint8List?)> files;

  const LocalFiles({required this.name, required this.files});
}

typedef LocalFolderRegistry = FolderRegistry<LocalFolder>;

String _baseName(String path) {
  final trimmed = path.replaceAll('\\', '/').replaceAll(RegExp(r'/+$'), '');
  final slash = trimmed.lastIndexOf('/');
  return slash < 0 ? trimmed : trimmed.substring(slash + 1);
}

String baseName(String path) => _baseName(path);

/// The same directory picked or dropped again refreshes one session root.
String localFolderIdentity(String path) =>
    path.replaceAll('\\', '/').replaceAll(RegExp(r'/+$'), '');
