import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// IndexedDB can structured-clone File System Access handles across reloads.
final class BrowserHandleStore {
  static const _databaseName = 'visualmd-source-access';
  static const _storeName = 'handles';

  Future<void> put(String key, web.FileSystemHandle handle) async {
    final database = await _open();
    try {
      final transaction = database.transaction(_storeName.toJS, 'readwrite');
      final completed = _transaction(transaction);
      final request = transaction.objectStore(_storeName).put(handle, key.toJS);
      try {
        await _request(request);
      } on Object {
        await completed.catchError((_) {});
        rethrow;
      }
      await completed;
    } finally {
      database.close();
    }
  }

  Future<web.FileSystemHandle?> get(String key) async {
    final database = await _open();
    try {
      final transaction = database.transaction(_storeName.toJS);
      final completed = _transaction(transaction);
      final JSAny? result;
      try {
        result = await _request(
          transaction.objectStore(_storeName).get(key.toJS),
        );
      } on Object {
        await completed.catchError((_) {});
        rethrow;
      }
      await completed;
      return result == null ? null : result as web.FileSystemHandle;
    } finally {
      database.close();
    }
  }

  Future<void> copy(String from, String to) async {
    final handle = await get(from);
    if (handle != null) await put(to, handle);
  }

  Future<web.IDBDatabase> _open() {
    final request = web.window.indexedDB.open(_databaseName, 1);
    final completer = Completer<web.IDBDatabase>();
    request.onupgradeneeded = ((web.Event _) {
      final database = request.result as web.IDBDatabase;
      database.createObjectStore(_storeName);
    }).toJS;
    request.onsuccess = ((web.Event _) {
      completer.complete(request.result as web.IDBDatabase);
    }).toJS;
    request.onerror = ((web.Event _) {
      completer.completeError(
        StateError(request.error?.message ?? 'IndexedDB open failed.'),
      );
    }).toJS;
    return completer.future;
  }

  Future<JSAny?> _request(web.IDBRequest request) {
    final completer = Completer<JSAny?>();
    request.onsuccess = ((web.Event _) => completer.complete(
      request.result,
    )).toJS;
    request.onerror = ((web.Event _) {
      completer.completeError(
        StateError(request.error?.message ?? 'IndexedDB request failed.'),
      );
    }).toJS;
    return completer.future;
  }

  Future<void> _transaction(web.IDBTransaction transaction) {
    final completer = Completer<void>();
    transaction.oncomplete = ((web.Event _) {
      if (!completer.isCompleted) completer.complete();
    }).toJS;
    transaction.onabort = ((web.Event _) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError(
            transaction.error?.message ?? 'IndexedDB transaction aborted.',
          ),
        );
      }
    }).toJS;
    transaction.onerror = ((web.Event _) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError(
            transaction.error?.message ?? 'IndexedDB transaction failed.',
          ),
        );
      }
    }).toJS;
    return completer.future;
  }
}
