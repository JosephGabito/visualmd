import '../application/ports/folder_scanner.dart';

/// Adapter composition: asks each scanner in turn; the first that recognises
/// the ref answers. Lets bundled and browser folders share one port.
final class RoutingFolderScanner
    implements FolderScanner, FolderMetadataScanner {
  final List<FolderScanner> _scanners;

  const RoutingFolderScanner(this._scanners);

  @override
  Future<ScannedFolder> scan(FolderRef ref) async {
    for (final scanner in _scanners) {
      try {
        return await scanner.scan(ref);
      } on FolderUnavailable {
        continue;
      }
    }
    throw FolderUnavailable(ref);
  }

  @override
  Future<ScannedFolder> scanMetadata(FolderRef ref) async {
    for (final scanner in _scanners) {
      try {
        if (scanner is FolderMetadataScanner) {
          return await (scanner as FolderMetadataScanner).scanMetadata(ref);
        }
        return await scanner.scan(ref);
      } on FolderUnavailable {
        continue;
      }
    }
    throw FolderUnavailable(ref);
  }

  @override
  Future<ScannedFolder> enrichTitles(
    FolderRef ref,
    ScannedFolder metadata,
  ) async {
    if (!metadata.titlesDeferred) return metadata;
    for (final scanner in _scanners.whereType<FolderMetadataScanner>()) {
      try {
        return await scanner.enrichTitles(ref, metadata);
      } on FolderUnavailable {
        continue;
      }
    }
    throw FolderUnavailable(ref);
  }
}
