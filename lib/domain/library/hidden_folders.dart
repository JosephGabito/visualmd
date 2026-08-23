/// Folders a library never shelves: tooling and dependency directories that
/// happen to contain markdown nobody came to read.
abstract final class HiddenFolders {
  /// Names that reliably identify dependency or generated runtime trees.
  ///
  /// Generic output names such as `build`, `dist`, `out`, and `target` stay
  /// visible: they can just as plausibly contain documentation someone meant
  /// to read. Dot-prefixed tooling directories are handled separately below.
  static const names = {
    '.git',
    '__pycache__',
    '__pypackages__',
    'bower_components',
    'Carthage',
    'DerivedData',
    'jspm_packages',
    'node_modules',
    'Pods',
    'site-packages',
    'vendor',
    'venv',
  };

  static bool isHidden(String folderName) =>
      folderName.startsWith('.') || names.contains(folderName);

  /// True when any folder segment of [path] is hidden.
  static bool hidesPath(String path) {
    final segments = path.replaceAll('\\', '/').split('/');
    for (var i = 0; i < segments.length - 1; i++) {
      if (isHidden(segments[i])) return true;
    }
    return false;
  }
}
