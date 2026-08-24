// ignore_for_file: prefer_initializing_formals — named parameters describe the composition contract.

import 'dart:async';

import '../domain/library/document_id.dart';
import '../domain/library/library.dart';
import 'ports/folder_scanner.dart';
import 'ports/markdown_scanner.dart';
import 'ports/source_change_monitor.dart';
import 'use_cases/refresh_source.dart';

sealed class SourceSyncEvent {
  const SourceSyncEvent();
}

final class SourceSynchronized extends SourceSyncEvent {
  final RefreshedSource result;
  const SourceSynchronized(this.result);
}

final class SourceSynchronizationFailed extends SourceSyncEvent {
  final String sourceName;
  final String reason;

  const SourceSynchronizationFailed(this.sourceName, this.reason);
}

/// Owns watcher lifetimes and turns noisy platform events into ordered refreshes.
final class SourceWatchCoordinator {
  final SourceChangeMonitor _monitor;
  final RefreshSource _refresh;
  final DocumentId? Function() _currentSelection;
  final Duration quietPeriod;
  final _events = StreamController<SourceSyncEvent>.broadcast(sync: true);
  final _folders = <String, _PendingWatch>{};
  final _markdowns = <String, _PendingWatch>{};
  var _disposed = false;

  SourceWatchCoordinator({
    required SourceChangeMonitor monitor,
    required RefreshSource refresh,
    required DocumentId? Function() currentSelection,
    this.quietPeriod = const Duration(milliseconds: 250),
  }) : _monitor = monitor,
       _refresh = refresh,
       _currentSelection = currentSelection;

  Stream<SourceSyncEvent> get events => _events.stream;

  void watchFolder(FolderRef folder) {
    if (_disposed) return;
    unwatchFolder(folder.id);
    final pending = _PendingWatch(folderName: folder.name, folder: folder);
    _folders[folder.id] = pending;
    pending.subscription = _monitor
        .watchFolder(folder)
        .listen(
          (change) => _receive(pending, change),
          onError: (Object failure) => _failed(pending, failure.toString()),
        );
  }

  void watchMarkdown(MarkdownRef markdown) {
    if (_disposed) return;
    unwatchMarkdown(markdown.id);
    final pending = _PendingWatch(
      folderName: markdown.name,
      markdown: markdown,
    );
    _markdowns[markdown.id] = pending;
    pending.subscription = _monitor
        .watchMarkdown(markdown)
        .listen(
          (change) => _receive(pending, change),
          onError: (Object failure) => _failed(pending, failure.toString()),
        );
  }

  void unwatchFolder(String id) => _cancel(_folders.remove(id));

  void unwatchMarkdown(String id) => _cancel(_markdowns.remove(id));

  /// Stops watches whose source was removed or absorbed into another root.
  void retainLibrary(Library? library) {
    final folderIds = {
      for (final root in library?.roots ?? const []) root.id.value,
    };
    final markdownIds = {
      for (final document in library?.markdowns ?? const [])
        _standaloneRefId(document.id),
    };
    for (final id in _folders.keys.toList()) {
      if (!folderIds.contains(id)) {
        unwatchFolder(id);
      }
    }
    for (final id in _markdowns.keys.toList()) {
      if (!markdownIds.contains(id)) {
        unwatchMarkdown(id);
      }
    }
  }

  void replace({
    required Iterable<FolderRef> folders,
    required Iterable<MarkdownRef> markdowns,
  }) {
    for (final pending in [..._folders.values, ..._markdowns.values]) {
      _cancel(pending);
    }
    _folders.clear();
    _markdowns.clear();
    for (final folder in folders) {
      watchFolder(folder);
    }
    for (final markdown in markdowns) {
      watchMarkdown(markdown);
    }
  }

  void _receive(_PendingWatch pending, SourceChange change) {
    if (_disposed || !pending.active) return;
    switch (change) {
      case FolderDocumentsInvalidated(:final relativePaths):
        pending.paths.addAll(relativePaths);
      case FolderRescanRequested():
        pending.rescan = true;
        pending.paths.clear();
      case MarkdownInvalidated():
        pending.markdownInvalidated = true;
      case SourceWatchFailed(:final sourceName, :final reason):
        _emit(SourceSynchronizationFailed(sourceName, reason));
        return;
    }
    pending.timer?.cancel();
    pending.timer = Timer(quietPeriod, () => _flush(pending));
  }

  Future<void> _flush(_PendingWatch pending) async {
    if (_disposed || !pending.active) return;
    pending.timer = null;
    if (pending.running) {
      pending.dueAfterRun = true;
      return;
    }
    final change = pending.takeChange();
    if (change == null) return;
    pending.running = true;
    try {
      final result = await _refresh.execute(
        change,
        selected: _currentSelection(),
        isCurrent: () => pending.active,
      );
      if (pending.active && result.changed) _emit(SourceSynchronized(result));
    } on Object catch (failure) {
      if (pending.active) _failed(pending, failure.toString());
    } finally {
      pending.running = false;
      if (pending.active && (pending.dueAfterRun || pending.hasChange)) {
        pending.dueAfterRun = false;
        unawaited(_flush(pending));
      }
    }
  }

  void _failed(_PendingWatch pending, String reason) =>
      _emit(SourceSynchronizationFailed(pending.folderName, reason));

  void _emit(SourceSyncEvent event) {
    if (!_disposed) _events.add(event);
  }

  void _cancel(_PendingWatch? pending) {
    if (pending == null) return;
    pending.active = false;
    pending.timer?.cancel();
    unawaited(pending.subscription?.cancel());
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final pending in [..._folders.values, ..._markdowns.values]) {
      pending.timer?.cancel();
      await pending.subscription?.cancel();
    }
    _folders.clear();
    _markdowns.clear();
    await _events.close();
  }
}

final class _PendingWatch {
  final String folderName;
  final FolderRef? folder;
  final MarkdownRef? markdown;
  final paths = <String>{};
  StreamSubscription<SourceChange>? subscription;
  Timer? timer;
  bool rescan = false;
  bool markdownInvalidated = false;
  bool running = false;
  bool dueAfterRun = false;
  bool active = true;

  _PendingWatch({required this.folderName, this.folder, this.markdown});

  bool get hasChange => rescan || paths.isNotEmpty || markdownInvalidated;

  SourceChange? takeChange() {
    final folder = this.folder;
    if (folder != null) {
      if (rescan) {
        rescan = false;
        paths.clear();
        return FolderRescanRequested(folder);
      }
      if (paths.isNotEmpty) {
        final changed = {...paths};
        paths.clear();
        return FolderDocumentsInvalidated(folder, changed);
      }
      return null;
    }
    final markdown = this.markdown;
    if (markdown != null && markdownInvalidated) {
      markdownInvalidated = false;
      return MarkdownInvalidated(markdown);
    }
    return null;
  }
}

String _standaloneRefId(DocumentId id) {
  const prefix = 'standalone-markdown:';
  return id.rootId.value.startsWith(prefix)
      ? id.rootId.value.substring(prefix.length)
      : id.rootId.value;
}
