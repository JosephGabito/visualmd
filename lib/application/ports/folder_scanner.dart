import '../../domain/library/library_builder.dart';

/// A folder the reader has offered to the app (dropped, picked, bundled).
/// Opaque to the application; the adapter that issued it knows what it means.
final class FolderRef {
  final String id;
  final String name;

  const FolderRef({required this.id, required this.name});

  @override
  bool operator ==(Object other) => other is FolderRef && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'FolderRef($id, $name)';
}

/// Everything found under a folder. Adapters read bytes; the domain shelves them.
final class ScannedFolder {
  final String name;
  final List<FileEntry> files;
  final bool titlesDeferred;

  const ScannedFolder({
    required this.name,
    required this.files,
    this.titlesDeferred = false,
  });
}

/// Port: reads the files beneath a [FolderRef].
abstract interface class FolderScanner {
  Future<ScannedFolder> scan(FolderRef ref);
}

/// Optional two-phase scan for platforms that can discover shelf metadata
/// without opening every document.
abstract interface class FolderMetadataScanner {
  Future<ScannedFolder> scanMetadata(FolderRef ref);

  Future<ScannedFolder> enrichTitles(FolderRef ref, ScannedFolder metadata);
}

/// The ref is unknown to this scanner, or the folder is no longer reachable.
final class FolderUnavailable implements Exception {
  final FolderRef ref;
  const FolderUnavailable(this.ref);

  @override
  String toString() => 'FolderUnavailable: $ref';
}
