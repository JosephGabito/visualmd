import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../../application/ports/workspace_files.dart';
import 'browser_file_system_access.dart';

final class BrowserWorkspaceFiles implements WorkspaceFiles {
  final _files = <String, _BrowserWorkspaceFile>{};
  var _next = 0;

  @override
  Future<WorkspaceFileRef?> pickOpen() async {
    final result = await pickWorkspaceFile();
    if (result.value case final handle?) {
      final id = 'workspace-file-${_next++}';
      _files[id] = _BrowserWorkspaceFile(name: handle.name, handle: handle);
      return WorkspaceFileRef(id: id, name: handle.name);
    }
    if (result.supported) return null;
    return _pickUpload();
  }

  Future<WorkspaceFileRef?> _pickUpload() {
    final input = web.document.createElement('input') as web.HTMLInputElement
      ..type = 'file'
      ..accept = '.json,.visualmd-workspace.json,application/json'
      ..style.display = 'none';
    web.document.body!.append(input);
    final completer = Completer<WorkspaceFileRef?>();
    void finish(WorkspaceFileRef? result) {
      input.remove();
      if (!completer.isCompleted) completer.complete(result);
    }

    input.addEventListener(
      'change',
      ((web.Event _) {
        final file = input.files?.item(0);
        if (file == null) return finish(null);
        final id = 'workspace-file-${_next++}';
        _files[id] = _BrowserWorkspaceFile(name: file.name, upload: file);
        finish(
          WorkspaceFileRef(
            id: id,
            name: file.name,
            supportsAutomaticWrites: false,
          ),
        );
      }).toJS,
    );
    input.addEventListener('cancel', ((web.Event _) => finish(null)).toJS);
    input.click();
    return completer.future;
  }

  @override
  Future<WorkspaceFileRef?> pickSave({required String suggestedName}) async {
    final result = await saveWorkspaceFile(suggestedName);
    if (result.supported && result.value == null) return null;
    final handle = result.value;
    final id = 'workspace-file-${_next++}';
    _files[id] = _BrowserWorkspaceFile(
      name: handle?.name ?? suggestedName,
      handle: handle,
    );
    return WorkspaceFileRef(
      id: id,
      name: handle?.name ?? suggestedName,
      supportsAutomaticWrites: handle != null,
    );
  }

  @override
  Future<String> read(WorkspaceFileRef file) async {
    final source = _files[file.id];
    if (source == null) {
      throw StateError('The workspace file is no longer open.');
    }
    final blob = source.handle == null
        ? source.upload
        : await source.handle!.getFile().toDart;
    if (blob == null) throw StateError('The workspace file is unavailable.');
    return (await blob.text().toDart).toDart;
  }

  @override
  Future<void> write(WorkspaceFileRef file, String contents) async {
    final target = _files[file.id];
    if (target?.handle case final handle?) {
      final writable = await handle.createWritable().toDart;
      await writable.write(contents.toJS).toDart;
      await writable.close().toDart;
      return;
    }
    final blob = web.Blob(
      <web.BlobPart>[contents.toJS].toJS,
      web.BlobPropertyBag(type: 'application/json'),
    );
    final url = web.URL.createObjectURL(blob);
    final anchor = web.document.createElement('a') as web.HTMLAnchorElement
      ..href = url
      ..download = file.name;
    web.document.body!.append(anchor);
    anchor.click();
    anchor.remove();
    web.URL.revokeObjectURL(url);
  }
}

final class _BrowserWorkspaceFile {
  final String name;
  final web.FileSystemFileHandle? handle;
  final web.File? upload;

  const _BrowserWorkspaceFile({required this.name, this.handle, this.upload});
}
