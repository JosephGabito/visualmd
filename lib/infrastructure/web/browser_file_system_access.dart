@JS()
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

@JS('showOpenFilePicker')
external JSPromise<JSArray<web.FileSystemFileHandle>> _showOpenFilePicker();

@JS('showSaveFilePicker')
external JSPromise<web.FileSystemFileHandle> _showSaveFilePicker(
  _SavePickerOptions options,
);

@JS('showDirectoryPicker')
external JSPromise<web.FileSystemDirectoryHandle> _showDirectoryPicker();

extension type _SavePickerOptions._(JSObject _) implements JSObject {
  external factory _SavePickerOptions({String suggestedName});
}

extension type _PermissionDescriptor._(JSObject _) implements JSObject {
  external factory _PermissionDescriptor({String mode});
}

extension type _PermissionHandle._(JSObject _) implements JSObject {
  external JSPromise<JSString> queryPermission(
    _PermissionDescriptor descriptor,
  );
  external JSPromise<JSString> requestPermission(
    _PermissionDescriptor descriptor,
  );
}

bool get supportsOpenFilePicker => globalContext.has('showOpenFilePicker');
bool get supportsSaveFilePicker => globalContext.has('showSaveFilePicker');
bool get supportsDirectoryPicker => globalContext.has('showDirectoryPicker');

/// Distinguishes an unavailable API from a user cancelling an available one.
/// Without that distinction, cancellation opens a second legacy chooser.
final class BrowserPickerResult<T> {
  final bool supported;
  final T? value;

  const BrowserPickerResult.unsupported() : supported = false, value = null;
  const BrowserPickerResult.selected(this.value) : supported = true;
}

Future<BrowserPickerResult<web.FileSystemFileHandle>>
pickWorkspaceFile() async {
  if (!supportsOpenFilePicker) {
    return const BrowserPickerResult.unsupported();
  }
  try {
    final handles = (await _showOpenFilePicker().toDart).toDart;
    return BrowserPickerResult.selected(handles.isEmpty ? null : handles.first);
  } on Object catch (error) {
    if (_isPickerCancellation(error)) {
      return const BrowserPickerResult.selected(null);
    }
    rethrow;
  }
}

Future<BrowserPickerResult<web.FileSystemFileHandle>> saveWorkspaceFile(
  String suggestedName,
) async {
  if (!supportsSaveFilePicker) {
    return const BrowserPickerResult.unsupported();
  }
  try {
    return BrowserPickerResult.selected(
      await _showSaveFilePicker(
        _SavePickerOptions(suggestedName: suggestedName),
      ).toDart,
    );
  } on Object catch (error) {
    if (_isPickerCancellation(error)) {
      return const BrowserPickerResult.selected(null);
    }
    rethrow;
  }
}

Future<BrowserPickerResult<web.FileSystemDirectoryHandle>>
pickDirectoryHandle() async {
  if (!supportsDirectoryPicker) {
    return const BrowserPickerResult.unsupported();
  }
  try {
    return BrowserPickerResult.selected(await _showDirectoryPicker().toDart);
  } on Object catch (error) {
    if (_isPickerCancellation(error)) {
      return const BrowserPickerResult.selected(null);
    }
    rethrow;
  }
}

Future<bool> ensureReadPermission(web.FileSystemHandle handle) async {
  final permission = _PermissionHandle._(handle as JSObject);
  final descriptor = _PermissionDescriptor(mode: 'read');
  final current = (await permission.queryPermission(descriptor).toDart).toDart;
  if (current == 'granted') return true;
  if (current == 'denied') return false;
  try {
    return (await permission.requestPermission(descriptor).toDart).toDart ==
        'granted';
  } on Object {
    return false;
  }
}

bool _isPickerCancellation(Object error) {
  if (!error.isA<JSObject>()) return false;
  final jsError = error as JSObject;
  if (!jsError.has('name')) return false;
  return jsError.getProperty<JSString>('name'.toJS).toDart == 'AbortError';
}
