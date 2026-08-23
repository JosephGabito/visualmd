import '../application/ports/folder_scanner.dart';

/// Adapter composition: asks each scanner in turn; the first that recognises
/// the ref answers. Lets bundled and browser folders share one port.
final class RoutingFolderScanner implements FolderScanner {
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
}
