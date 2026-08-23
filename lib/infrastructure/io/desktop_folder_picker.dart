import 'package:file_selector/file_selector.dart';

import '../../application/ports/folder_scanner.dart';
import 'local_folder.dart';

/// Adapter: the native "choose a folder" dialog. On macOS the open panel
/// grants sandbox access to whatever the reader picks.
final class DesktopFolderPicker {
  final LocalFolderRegistry _registry;

  const DesktopFolderPicker(this._registry);

  Future<FolderRef?> pick() async {
    final path = await getDirectoryPath(confirmButtonText: 'Open library');
    if (path == null) return null;
    final folder = LocalDirectory(path);
    return _registry.register(
      folder.name,
      folder,
      identity: localFolderIdentity(folder.path),
    );
  }
}
