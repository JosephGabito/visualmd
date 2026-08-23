// ignore_for_file: prefer_initializing_formals — named parameters describe the composition contract.

import 'dart:async';

import 'library_mutation_queue.dart';
import 'ports/workspace_codec.dart';
import 'ports/workspace_files.dart';
import 'ports/workspace_session_repository.dart';

/// Coalesces quiet workspace changes and flushes their latest durable state.
final class WorkspaceAutosave {
  final WorkspaceSessionRepository _sessions;
  final WorkspaceFiles _files;
  final WorkspaceCodec _codec;
  final LibraryMutationQueue _mutations;
  final Duration delay;
  final _failures = StreamController<Object>.broadcast();
  Timer? _timer;

  WorkspaceAutosave({
    required WorkspaceSessionRepository sessions,
    required WorkspaceFiles files,
    required WorkspaceCodec codec,
    required LibraryMutationQueue mutations,
    this.delay = const Duration(milliseconds: 300),
  }) : _sessions = sessions,
       _files = files,
       _codec = codec,
       _mutations = mutations;

  void schedule() {
    _timer?.cancel();
    _timer = Timer(delay, () => unawaited(_flushAfterDelay()));
  }

  Stream<Object> get failures => _failures.stream;

  Future<void> _flushAfterDelay() async {
    try {
      await flush();
    } on Object catch (failure) {
      _failures.add(failure);
    }
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  Future<WorkspaceSession?> flush() {
    cancel();
    return _mutations.run(() async {
      final current = await _sessions.current();
      final file = current?.file;
      if (current == null ||
          file == null ||
          !file.supportsAutomaticWrites ||
          !current.dirty) {
        return current;
      }
      await _files.write(file, _codec.encode(current.workspace));
      final saved = current.copyWith(dirty: false);
      await _sessions.save(saved);
      return saved;
    });
  }
}
