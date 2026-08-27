import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/application/ports/mermaid_renderer.dart';
import 'package:visualmd/infrastructure/mermaid/mermaid_render_cache.dart';

void main() {
  MermaidRendering rendering(String marker, {int length = 100}) =>
      MermaidRendering(svg: marker.padRight(length, marker));

  test(
    'completed renderings evict by retained bytes in least-recent order',
    () async {
      final cache = MermaidRenderCache(maximumRetainedBytes: 1200);
      final calls = <String, int>{};

      Future<MermaidRendering> load(String key) async {
        calls.update(key, (count) => count + 1, ifAbsent: () => 1);
        return rendering(key);
      }

      await cache.resolve('a', () => load('a'));
      await cache.resolve('b', () => load('b'));
      await cache.resolve('a', () => load('a'));
      await cache.resolve('c', () => load('c'));
      await cache.resolve('b', () => load('b'));

      expect(calls, {'a': 1, 'b': 2, 'c': 1});
      expect(cache.completedEntries, 2);
      expect(
        cache.retainedBytes,
        lessThanOrEqualTo(cache.maximumRetainedBytes),
      );
    },
  );

  test('one oversized SVG is returned but never retained', () async {
    final cache = MermaidRenderCache(maximumRetainedBytes: 300);
    var calls = 0;

    Future<MermaidRendering> load() async {
      calls++;
      return rendering('x', length: 1000);
    }

    await cache.resolve('large', load);
    await cache.resolve('large', load);

    expect(calls, 2);
    expect(cache.completedEntries, 0);
    expect(cache.retainedBytes, 0);
  });

  test('concurrent requests for one diagram share the active render', () async {
    final cache = MermaidRenderCache();
    final pending = Completer<MermaidRendering>();
    var calls = 0;

    Future<MermaidRendering> load() {
      calls++;
      return pending.future;
    }

    final first = cache.resolve('same', load);
    final second = cache.resolve('same', load);
    expect(identical(first, second), isTrue);
    expect(calls, 1);
    expect(cache.inFlightEntries, 1);

    pending.complete(rendering('done'));
    await first;
    expect(cache.inFlightEntries, 0);
    expect(cache.completedEntries, 1);
  });

  test('a failed render does not poison a later retry', () async {
    final cache = MermaidRenderCache();
    var calls = 0;

    Future<MermaidRendering> load() async {
      calls++;
      if (calls == 1) throw StateError('broken');
      return rendering('recovered');
    }

    await expectLater(cache.resolve('retry', load), throwsStateError);
    expect(cache.inFlightEntries, 0);
    await cache.resolve('retry', load);

    expect(calls, 2);
    expect(cache.completedEntries, 1);
  });
}
