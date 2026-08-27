import 'dart:collection';

import '../../application/ports/mermaid_renderer.dart';

/// Deduplicates active Mermaid work and retains completed SVG by byte budget.
///
/// A diagram can be far larger than its source, so an entry-count limit would
/// not bound memory. The estimate deliberately charges two bytes per string
/// code unit plus a fixed object allowance; it may evict early, but it cannot
/// silently turn one enormous SVG into a permanent application-lifetime cache.
final class MermaidRenderCache {
  static const defaultMaximumRetainedBytes = 32 * 1024 * 1024;
  static const _entryOverheadBytes = 256;

  final int maximumRetainedBytes;
  final LinkedHashMap<String, _CachedMermaidRendering> _completed =
      LinkedHashMap();
  final Map<String, Future<MermaidRendering>> _inFlight = {};
  var _retainedBytes = 0;

  MermaidRenderCache({
    this.maximumRetainedBytes = defaultMaximumRetainedBytes,
  }) {
    if (maximumRetainedBytes < 0) {
      throw RangeError.value(maximumRetainedBytes, 'maximumRetainedBytes');
    }
  }

  int get retainedBytes => _retainedBytes;
  int get completedEntries => _completed.length;
  int get inFlightEntries => _inFlight.length;

  Future<MermaidRendering> resolve(
    String key,
    Future<MermaidRendering> Function() load,
  ) {
    final cached = _completed.remove(key);
    if (cached != null) {
      _completed[key] = cached;
      return Future.value(cached.rendering);
    }
    final active = _inFlight[key];
    if (active != null) return active;

    final pending = _load(key, load);
    _inFlight[key] = pending;
    return pending;
  }

  Future<MermaidRendering> _load(
    String key,
    Future<MermaidRendering> Function() load,
  ) async {
    try {
      final rendering = await load();
      _inFlight.remove(key);
      _retain(key, rendering);
      return rendering;
    } on Object {
      _inFlight.remove(key);
      rethrow;
    }
  }

  void _retain(String key, MermaidRendering rendering) {
    final entry = _CachedMermaidRendering(key, rendering);
    if (entry.retainedBytes > maximumRetainedBytes) return;
    _completed[key] = entry;
    _retainedBytes += entry.retainedBytes;
    while (_retainedBytes > maximumRetainedBytes) {
      final oldest = _completed.remove(_completed.keys.first)!;
      _retainedBytes -= oldest.retainedBytes;
    }
  }
}

final class _CachedMermaidRendering {
  final MermaidRendering rendering;
  final int retainedBytes;

  _CachedMermaidRendering(String key, this.rendering)
    : retainedBytes =
          MermaidRenderCache._entryOverheadBytes +
          2 *
              (key.length +
                  rendering.svg.length +
                  (rendering.title?.length ?? 0) +
                  (rendering.description?.length ?? 0));
}
