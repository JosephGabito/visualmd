import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../../application/ports/folder_scanner.dart';
import 'browser_file_system_access.dart';
import 'browser_folder.dart';

/// Adapter: opens the browser's folder chooser (`<input webkitdirectory>`),
/// which works everywhere a drop does, including Firefox and Safari.
final class BrowserFolderPicker {
  final BrowserFolderRegistry _registry;

  const BrowserFolderPicker(this._registry);

  /// Resolves to null when the reader cancels the dialog.
  Future<FolderRef?> pick() async {
    final result = await pickDirectoryHandle();
    if (result.value case final handle?) {
      final folder = HandleDirectory(handle);
      return _registry.register(folder.name, folder);
    }
    if (result.supported) return null;
    return _pickLegacy();
  }

  Future<FolderRef?> _pickLegacy() {
    final input = web.document.createElement('input') as web.HTMLInputElement
      ..type = 'file'
      ..webkitdirectory = true
      ..style.display = 'none';
    web.document.body!.append(input);

    final completer = Completer<FolderRef?>();
    void finish(FolderRef? ref) {
      input.remove();
      if (!completer.isCompleted) completer.complete(ref);
    }

    input.addEventListener(
      'change',
      ((web.Event _) => finish(_folderFrom(input.files))).toJS,
    );
    input.addEventListener('cancel', ((web.Event _) => finish(null)).toJS);
    input.click();
    return completer.future;
  }

  FolderRef? _folderFrom(web.FileList? list) {
    if (list == null || list.length == 0) return null;
    String? name;
    final files = <(String, web.File)>[];
    for (var i = 0; i < list.length; i++) {
      final file = list.item(i)!;
      // "picked/sub/file.md" — the first segment is the folder that was picked.
      final segments = file.webkitRelativePath.split('/');
      if (segments.length < 2) continue;
      name ??= segments.first;
      files.add((segments.sublist(1).join('/'), file));
    }
    if (name == null) return null;
    return _registry.register(name, PickedFiles(name: name, files: files));
  }
}
