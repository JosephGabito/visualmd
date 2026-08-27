// ignore_for_file: prefer_initializing_formals — public names describe the protocol.

import 'dart:async';

import '../domain/library/document_id.dart';
import '../domain/reading/content/document_content.dart';
import 'ports/document_parser.dart';

final class DocumentStreamId {
  final String value;

  const DocumentStreamId(this.value) : assert(value != '');

  @override
  bool operator ==(Object other) =>
      other is DocumentStreamId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

/// One ordered transport operation after a stream session has been opened.
sealed class GeneratedDocumentEvent {
  final DocumentStreamId streamId;
  final int sequence;

  const GeneratedDocumentEvent({
    required this.streamId,
    required this.sequence,
  });
}

final class GeneratedDocumentDelta extends GeneratedDocumentEvent {
  final int sourceOffset;
  final String source;

  const GeneratedDocumentDelta({
    required super.streamId,
    required super.sequence,
    required this.sourceOffset,
    required this.source,
  });
}

final class GeneratedDocumentFinished extends GeneratedDocumentEvent {
  final int sourceLength;

  const GeneratedDocumentFinished({
    required super.streamId,
    required super.sequence,
    required this.sourceLength,
  });
}

final class GeneratedDocumentFailed extends GeneratedDocumentEvent {
  final String reason;

  const GeneratedDocumentFailed({
    required super.streamId,
    required super.sequence,
    required this.reason,
  });
}

enum GeneratedDocumentStatus { streaming, finished, failed }

/// One lossless parser commit published to downstream projections and UI.
final class GeneratedDocumentRevision {
  final DocumentId documentId;
  final DocumentStreamId streamId;
  final int throughSequence;
  final int acceptedSourceLength;
  final int parsedSourceCharacters;
  final DocumentContent content;
  final GeneratedDocumentStatus status;
  final String? failure;

  const GeneratedDocumentRevision({
    required this.documentId,
    required this.streamId,
    required this.throughSequence,
    required this.acceptedSourceLength,
    required this.parsedSourceCharacters,
    required this.content,
    required this.status,
    this.failure,
  });
}

final class GeneratedDocumentProtocolException implements Exception {
  final String message;

  const GeneratedDocumentProtocolException(this.message);

  @override
  String toString() => 'GeneratedDocumentProtocolException: $message';
}

/// Orders, coalesces, parses, and fences one generated Markdown stream.
///
/// Tiny transport chunks are joined only inside a bounded pending batch. A
/// blank-line boundary publishes immediately; otherwise [maxLatency] caps how
/// long readable text waits and [maxBatchCharacters] caps queued source. The
/// parser still owns Markdown's committed/provisional boundary.
final class GeneratedDocumentStreamSession {
  final DocumentId documentId;
  final DocumentStreamId streamId;
  final Duration maxLatency;
  final int maxBatchCharacters;
  final IncrementalDocumentParserSession _parser;
  final StreamController<GeneratedDocumentRevision> _revisions =
      StreamController.broadcast(sync: true);
  final List<String> _pending = [];

  Timer? _flushTimer;
  int _nextSequence = 0;
  int _acceptedSourceLength = 0;
  int _pendingCharacters = 0;
  int _pendingThroughSequence = -1;
  bool _closed = false;

  GeneratedDocumentStreamSession({
    required this.documentId,
    required this.streamId,
    required IncrementalDocumentParser parser,
    this.maxLatency = const Duration(milliseconds: 24),
    this.maxBatchCharacters = 4096,
  }) : _parser = parser.startSession() {
    if (maxLatency.isNegative) {
      throw ArgumentError.value(maxLatency, 'maxLatency');
    }
    if (maxBatchCharacters <= 0) {
      throw RangeError.value(
        maxBatchCharacters,
        'maxBatchCharacters',
        'must be positive',
      );
    }
  }

  Stream<GeneratedDocumentRevision> get revisions => _revisions.stream;

  int get acceptedSourceLength => _acceptedSourceLength;

  int get queuedSourceLength => _pendingCharacters;

  bool get isClosed => _closed;

  /// Accepts an event. Returns false for a duplicate, stale generation, or a
  /// chunk arriving after this session was fenced.
  bool accept(GeneratedDocumentEvent event) {
    if (_closed || event.streamId != streamId) return false;
    if (event.sequence < _nextSequence) return false;
    if (event.sequence > _nextSequence) {
      throw GeneratedDocumentProtocolException(
        'Expected sequence $_nextSequence, received ${event.sequence}.',
      );
    }

    switch (event) {
      case GeneratedDocumentDelta(:final sourceOffset, :final source):
        if (sourceOffset != _acceptedSourceLength) {
          throw GeneratedDocumentProtocolException(
            'Expected source offset $_acceptedSourceLength, '
            'received $sourceOffset.',
          );
        }
        _nextSequence++;
        _acceptedSourceLength += source.length;
        if (source.isEmpty) return true;
        _pending.add(source);
        _pendingCharacters += source.length;
        _pendingThroughSequence = event.sequence;
        if (_pendingCharacters >= maxBatchCharacters ||
            _endsAtMarkdownBoundary(source)) {
          _flush();
        } else {
          _armTimer();
        }
      case GeneratedDocumentFinished(:final sourceLength):
        if (sourceLength != _acceptedSourceLength) {
          throw GeneratedDocumentProtocolException(
            'Finish declared $sourceLength source characters after '
            '$_acceptedSourceLength were accepted.',
          );
        }
        _nextSequence++;
        _flush(emit: false);
        final content = _parser.finish();
        _emit(
          throughSequence: event.sequence,
          content: content,
          status: GeneratedDocumentStatus.finished,
        );
        _close();
      case GeneratedDocumentFailed(:final reason):
        _nextSequence++;
        _flush(emit: false);
        _emit(
          throughSequence: event.sequence,
          content: _parser.content,
          status: GeneratedDocumentStatus.failed,
          failure: reason,
        );
        _close();
    }
    return true;
  }

  /// Fences the generation without interpreting queued late source.
  Future<void> cancel() async {
    if (_closed) return;
    _closed = true;
    _flushTimer?.cancel();
    _flushTimer = null;
    _pending.clear();
    _pendingCharacters = 0;
    await _closeRevisions();
  }

  void _armTimer() {
    if (_flushTimer != null) return;
    if (maxLatency == Duration.zero) {
      _flush();
      return;
    }
    _flushTimer = Timer(maxLatency, _flush);
  }

  void _flush({bool emit = true}) {
    _flushTimer?.cancel();
    _flushTimer = null;
    if (_pending.isEmpty || _closed) return;
    final text = _pending.length == 1
        ? _pending.single
        : (StringBuffer()..writeAll(_pending)).toString();
    final throughSequence = _pendingThroughSequence;
    _pending.clear();
    _pendingCharacters = 0;
    _pendingThroughSequence = -1;
    final content = _parser.append(text);
    if (emit) {
      _emit(
        throughSequence: throughSequence,
        content: content,
        status: GeneratedDocumentStatus.streaming,
      );
    }
  }

  void _emit({
    required int throughSequence,
    required DocumentContent content,
    required GeneratedDocumentStatus status,
    String? failure,
  }) {
    if (_revisions.isClosed) return;
    _revisions.add(
      GeneratedDocumentRevision(
        documentId: documentId,
        streamId: streamId,
        throughSequence: throughSequence,
        acceptedSourceLength: _acceptedSourceLength,
        parsedSourceCharacters: _parser.lastParsedSourceLength,
        content: content,
        status: status,
        failure: failure,
      ),
    );
  }

  void _close() {
    _closed = true;
    _flushTimer?.cancel();
    _flushTimer = null;
    unawaited(_closeRevisions());
  }

  Future<void> _closeRevisions() async {
    // A listener is allowed to cancel from inside a synchronous revision
    // callback. Closing on the next microtask avoids re-entering the broadcast
    // controller while it is still delivering that revision.
    await Future<void>.delayed(Duration.zero);
    if (!_revisions.isClosed) await _revisions.close();
  }

  static bool _endsAtMarkdownBoundary(String source) =>
      source.endsWith('\n\n') ||
      source.endsWith('\r\n\r\n') ||
      source.endsWith('\r\r');
}
