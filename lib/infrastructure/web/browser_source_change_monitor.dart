import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import '../../application/ports/folder_scanner.dart';
import '../../application/ports/markdown_scanner.dart';
import '../../application/ports/source_change_monitor.dart';
import '../../domain/library/hidden_folders.dart';
import '../../domain/library/markdown_file.dart';
import 'browser_folder.dart';
import 'browser_markdown.dart';

/// Browsers have no production-grade cross-browser filesystem observer.
/// Durable handles are therefore checked while the page is visible and once
/// whenever it regains focus. Legacy immutable File objects remain snapshots.
final class BrowserSourceChangeMonitor implements SourceChangeMonitor {
  static const interval = Duration(seconds: 5);

  final BrowserFolderRegistry _folders;
  final BrowserMarkdownRegistry _markdowns;

  const BrowserSourceChangeMonitor(this._folders, this._markdowns);

  @override
  Stream<SourceChange> watchFolder(FolderRef ref) {
    final folder = _folders.lookup(ref);
    return switch (folder) {
      HandleDirectory(:final handle) => _pollFolderHandle(ref, handle),
      DroppedDirectory(:final entry) => _pollDroppedFolder(ref, entry),
      PickedFiles() || null => const Stream.empty(),
    };
  }

  @override
  Stream<SourceChange> watchMarkdown(MarkdownRef ref) {
    final markdown = _markdowns.lookup(ref);
    return switch (markdown) {
      BrowserMarkdownHandle(:final handle) => _poll(
        sourceName: ref.name,
        fingerprint: () async {
          final file = await handle.getFile().toDart;
          return {'': '${file.lastModified}:${file.size}'};
        },
        changed: (_, _) => MarkdownInvalidated(ref),
      ),
      BrowserMarkdownFile() || null => const Stream.empty(),
    };
  }

  Stream<SourceChange> _pollFolderHandle(
    FolderRef ref,
    web.FileSystemDirectoryHandle handle,
  ) => _poll(
    sourceName: ref.name,
    fingerprint: () async {
      final files = <String, String>{};
      await _fingerprintHandle(handle, '', files);
      return files;
    },
    changed: (before, after) {
      final paths = _changedPaths(before, after);
      final removed = paths.any(
        (path) => before.containsKey(path) && !after.containsKey(path),
      );
      return removed
          ? FolderRescanRequested(ref)
          : FolderDocumentsInvalidated(ref, paths);
    },
  );

  Stream<SourceChange> _pollDroppedFolder(
    FolderRef ref,
    web.FileSystemDirectoryEntry entry,
  ) => _poll(
    sourceName: ref.name,
    fingerprint: () async {
      final files = <String, String>{};
      await _fingerprintEntry(entry, '', files);
      return files;
    },
    // Legacy entries can be rescanned, but cannot be addressed reliably one
    // file at a time across browsers.
    changed: (_, _) => FolderRescanRequested(ref),
  );

  Stream<SourceChange> _poll({
    required String sourceName,
    required Future<Map<String, String>> Function() fingerprint,
    required SourceChange Function(
      Map<String, String> before,
      Map<String, String> after,
    )
    changed,
  }) {
    late final StreamController<SourceChange> controller;
    Timer? timer;
    Map<String, String>? previous;
    bool checking = false;
    bool closed = false;
    String? lastFailure;

    Future<void> check() async {
      if (closed || checking || web.document.visibilityState != 'visible') {
        return;
      }
      checking = true;
      try {
        final next = await fingerprint();
        final before = previous;
        previous = next;
        lastFailure = null;
        if (before != null && !_sameFingerprint(before, next)) {
          controller.add(changed(before, next));
        }
      } on Object catch (failure) {
        final reason = failure.toString();
        if (reason != lastFailure) {
          lastFailure = reason;
          controller.add(SourceWatchFailed(sourceName, reason));
        }
      } finally {
        checking = false;
      }
    }

    final onFocus = ((web.Event _) => unawaited(check())).toJS;
    final onVisibility = ((web.Event _) => unawaited(check())).toJS;
    controller = StreamController<SourceChange>(sync: true);
    controller.onListen = () {
      web.window.addEventListener('focus', onFocus);
      web.document.addEventListener('visibilitychange', onVisibility);
      timer = Timer.periodic(interval, (_) => unawaited(check()));
      unawaited(check());
    };
    controller.onCancel = () {
      closed = true;
      timer?.cancel();
      web.window.removeEventListener('focus', onFocus);
      web.document.removeEventListener('visibilitychange', onVisibility);
    };
    return controller.stream;
  }

  Future<void> _fingerprintHandle(
    web.FileSystemDirectoryHandle directory,
    String prefix,
    Map<String, String> out,
  ) async {
    final iterator = (directory as JSObject).callMethod<JSObject>(
      'values'.toJS,
    );
    while (true) {
      final result = await iterator
          .callMethod<JSPromise<JSObject>>('next'.toJS)
          .toDart;
      if (result.getProperty<JSBoolean>('done'.toJS).toDart) return;
      final handle = result.getProperty<JSObject>('value'.toJS);
      final entry = handle as web.FileSystemHandle;
      final path = '$prefix${entry.name}';
      if (entry.kind == 'directory') {
        if (HiddenFolders.isHidden(entry.name)) continue;
        await _fingerprintHandle(
          handle as web.FileSystemDirectoryHandle,
          '$path/',
          out,
        );
      } else if (MarkdownFile.isMarkdown(entry.name)) {
        final file = await (handle as web.FileSystemFileHandle)
            .getFile()
            .toDart;
        out[path] = '${file.lastModified}:${file.size}';
      }
    }
  }

  Future<void> _fingerprintEntry(
    web.FileSystemDirectoryEntry directory,
    String prefix,
    Map<String, String> out,
  ) async {
    for (final entry in await _entriesOf(directory)) {
      final path = '$prefix${entry.name}';
      if (entry.isDirectory) {
        if (HiddenFolders.isHidden(entry.name)) continue;
        await _fingerprintEntry(
          entry as web.FileSystemDirectoryEntry,
          '$path/',
          out,
        );
      } else if (entry.isFile && MarkdownFile.isMarkdown(entry.name)) {
        final file = await _fileOf(entry as web.FileSystemFileEntry);
        out[path] = '${file.lastModified}:${file.size}';
      }
    }
  }
}

Set<String> _changedPaths(
  Map<String, String> before,
  Map<String, String> after,
) => {
  for (final path in {...before.keys, ...after.keys})
    if (before[path] != after[path]) path,
};

bool _sameFingerprint(Map<String, String> before, Map<String, String> after) {
  if (before.length != after.length) return false;
  for (final entry in before.entries) {
    if (after[entry.key] != entry.value) return false;
  }
  return true;
}

Future<List<web.FileSystemEntry>> _entriesOf(
  web.FileSystemDirectoryEntry directory,
) async {
  final reader = directory.createReader();
  final all = <web.FileSystemEntry>[];
  while (true) {
    final completer = Completer<List<web.FileSystemEntry>>();
    reader.readEntries(
      ((JSArray<web.FileSystemEntry> entries) => completer.complete(
        entries.toDart,
      )).toJS,
      ((web.DOMException error) => completer.completeError(error.message)).toJS,
    );
    final batch = await completer.future;
    if (batch.isEmpty) return all;
    all.addAll(batch);
  }
}

Future<web.File> _fileOf(web.FileSystemFileEntry entry) {
  final completer = Completer<web.File>();
  entry.file(
    ((web.File file) => completer.complete(file)).toJS,
    ((web.DOMException error) => completer.completeError(error.message)).toJS,
  );
  return completer.future;
}
