import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:visualmd/api/theme/library_theme.dart';
import 'package:visualmd/api/widgets/reading_pane.dart';
import 'package:visualmd/application/use_cases/read_document.dart';
import 'package:visualmd/domain/library/document.dart';
import 'package:visualmd/domain/library/document_id.dart';
import 'package:visualmd/domain/library/library_root_id.dart';
import 'package:visualmd/domain/reading/content/block.dart';
import 'package:visualmd/domain/reading/content/document_content.dart';
import 'package:visualmd/domain/reading/document_outline.dart';
import 'package:visualmd/infrastructure/viewport/quiet_document_viewport_geometry.dart';
import 'package:visualmd/presentation/theme/built_in_themes.dart';
import 'package:visualmd/presentation/theme/reading_scale.dart';

/// Locates the point where one atomic Markdown block stops being boring.
///
/// Top-level sliver laziness cannot help while a single child owns thousands
/// of code lines. This profile-only benchmark records the current cost before
/// specialized code virtualization changes that representation.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('one code fence exposes its complete atomic layout cost', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final timings = <FrameTiming>[];
    void collect(List<FrameTiming> batch) => timings.addAll(batch);
    SchedulerBinding.instance.addTimingsCallback(collect);
    addTearDown(() => SchedulerBinding.instance.removeTimingsCallback(collect));

    await tester.pumpWidget(_app(_reading(100)));
    await tester.pumpAndSettle();
    await Future<void>.delayed(const Duration(milliseconds: 180));
    await tester.pump();

    final runs = <Map<String, Object?>>[];
    for (final lineCount in const [1000, 10000, 50000]) {
      final reading = _reading(lineCount);
      final beforeFrames = timings.length;
      final beforeRss = ProcessInfo.currentRss;
      final clock = Stopwatch()..start();

      await tester.pumpWidget(_app(reading));
      await tester.pumpAndSettle();
      clock.stop();
      await Future<void>.delayed(const Duration(milliseconds: 180));
      await tester.pump();

      final frames = timings.skip(beforeFrames).toList(growable: false);
      final scrollable = find.descendant(
        of: find.byType(CustomScrollView),
        matching: find.byType(Scrollable),
      );
      final position = tester.state<ScrollableState>(scrollable.first).position;
      runs.add({
        'lines': lineCount,
        'source_characters': reading.content.blocks.single.text.length,
        'open_wall_us': clock.elapsedMicroseconds,
        'maximum_scroll_extent': position.maxScrollExtent,
        'rss_delta_bytes': ProcessInfo.currentRss - beforeRss,
        'frames': _frameSummary(frames),
      });

      expect(find.byKey(const ValueKey('code-source')), findsOneWidget);
      expect(position.maxScrollExtent, greaterThan(0));
      expect(tester.takeException(), isNull);
    }

    binding.reportData = {
      'benchmark': 'atomic_code_block_scaling',
      'mode': 'profile',
      'viewport_logical_pixels': {'width': 1280, 'height': 820},
      'runs': runs,
    };
  });
}

Widget _app(DocumentReading reading) => MaterialApp(
  theme: libraryTheme(BuiltInThemes.paper),
  home: Scaffold(
    body: ReadingPane(
      reading: reading,
      scale: ReadingScale.comfortable,
      viewportGeometry: const QuietDocumentViewportGeometryFactory(),
      onLink: (_) {},
      onActiveHeadingChanged: (_) {},
    ),
  ),
);

DocumentReading _reading(int lineCount) {
  final source = List.generate(
    lineCount,
    (index) =>
        'final value_$index = compute(input_$index); // deterministic fixture',
    growable: false,
  ).join('\n');
  final documentSource = '```dart\n$source\n```';
  return DocumentReading(
    document: Document(
      id: DocumentId(
        const LibraryRootId('atomic-benchmark'),
        'code-$lineCount.md',
      ),
      content: documentSource,
      title: 'Atomic code benchmark',
    ),
    source: documentSource,
    outline: DocumentOutline.parse(''),
    content: DocumentContent([CodeBlock(code: source, language: 'dart')]),
  );
}

Map<String, Object> _frameSummary(List<FrameTiming> frames) {
  final builds = frames
      .map((frame) => frame.buildDuration.inMicroseconds)
      .toList(growable: false);
  final rasters = frames
      .map((frame) => frame.rasterDuration.inMicroseconds)
      .toList(growable: false);
  final totals = frames
      .map((frame) => frame.totalSpan.inMicroseconds)
      .toList(growable: false);
  return {
    'count': frames.length,
    'build_p50_us': _percentile(builds, 0.50),
    'build_p90_us': _percentile(builds, 0.90),
    'build_worst_us': builds.isEmpty ? 0 : builds.reduce(math.max),
    'raster_p50_us': _percentile(rasters, 0.50),
    'raster_p90_us': _percentile(rasters, 0.90),
    'raster_worst_us': rasters.isEmpty ? 0 : rasters.reduce(math.max),
    'total_p90_us': _percentile(totals, 0.90),
    'total_worst_us': totals.isEmpty ? 0 : totals.reduce(math.max),
  };
}

int _percentile(List<int> values, double percentile) {
  if (values.isEmpty) return 0;
  final sorted = [...values]..sort();
  final index = ((sorted.length - 1) * percentile).round();
  return sorted[index];
}
