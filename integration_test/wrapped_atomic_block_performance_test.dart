import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

/// Measures wrapped layout through the production windowed code path.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('wrapping one huge fence keeps mounted work viewport-bounded', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final timings = <FrameTiming>[];
    void collect(List<FrameTiming> batch) => timings.addAll(batch);
    SchedulerBinding.instance.addTimingsCallback(collect);
    addTearDown(() => SchedulerBinding.instance.removeTimingsCallback(collect));

    final runs = <Map<String, Object?>>[];
    for (final lineCount in const [1000, 10000, 50000]) {
      final reading = _reading(lineCount);
      await tester.pumpWidget(_app(reading));
      await tester.pumpAndSettle();
      await Future<void>.delayed(const Duration(milliseconds: 180));
      await tester.pump();

      final beforeFrames = timings.length;
      final beforeRss = ProcessInfo.currentRss;
      final clock = Stopwatch()..start();
      await tester.tap(find.byKey(const ValueKey('code-wrap')));
      await tester.pumpAndSettle();
      clock.stop();
      await Future<void>.delayed(const Duration(milliseconds: 180));
      await tester.pump();

      final mountedCharacters = find
          .descendant(
            of: find.byKey(const ValueKey('code-source')),
            matching: find.byType(RichText),
          )
          .evaluate()
          .map(
            (element) =>
                (element.renderObject! as RenderParagraph).text.toPlainText(),
          )
          .fold(0, (total, text) => total + text.length);
      final mountedLines = find
          .byWidgetPredicate((widget) {
            final key = widget.key;
            return key is ValueKey<String> &&
                key.value.startsWith('code-line-');
          })
          .evaluate()
          .length;
      runs.add({
        'lines': lineCount,
        'source_characters': reading.content.blocks.single.text.length,
        'wrap_wall_us': clock.elapsedMicroseconds,
        'rss_delta_bytes': ProcessInfo.currentRss - beforeRss,
        'mounted_characters': mountedCharacters,
        'mounted_lines': mountedLines,
        'frames': _frameSummary(
          timings.skip(beforeFrames).toList(growable: false),
        ),
      });

      expect(mountedCharacters, lessThan(20000));
      expect(mountedLines, lessThan(100));
      expect(tester.takeException(), isNull);
    }

    binding.reportData = {
      'benchmark': 'wrapped_atomic_code_block_scaling',
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
        'final value_$index = compute(input_$index) + another_operation_$index; '
        '// a deliberately long deterministic source row which wraps',
    growable: false,
  ).join('\n');
  final documentSource = '```dart\n$source\n```';
  return DocumentReading(
    document: Document(
      id: DocumentId(
        const LibraryRootId('wrapped-atomic-benchmark'),
        'code-$lineCount.md',
      ),
      content: documentSource,
      title: 'Wrapped atomic code benchmark',
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
  final totals = frames
      .map((frame) => frame.totalSpan.inMicroseconds)
      .toList(growable: false);
  return {
    'count': frames.length,
    'build_p90_us': _percentile(builds, 0.90),
    'build_worst_us': builds.isEmpty ? 0 : builds.reduce(math.max),
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
