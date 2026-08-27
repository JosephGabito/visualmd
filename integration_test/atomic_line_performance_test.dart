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

/// Measures the horizontal form of the atomic-block problem.
///
/// A vertical line window is insufficient when one source line itself is the
/// unbounded text object. This fixture records shaping, layout, retained memory
/// and horizontal seek behavior before and after column windowing.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('one generated line exposes its complete horizontal cost', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final timings = <FrameTiming>[];
    void collect(List<FrameTiming> batch) => timings.addAll(batch);
    SchedulerBinding.instance.addTimingsCallback(collect);
    addTearDown(() => SchedulerBinding.instance.removeTimingsCallback(collect));

    await tester.pumpWidget(_app(_reading(1000)));
    await tester.pumpAndSettle();
    await Future<void>.delayed(const Duration(milliseconds: 180));
    await tester.pump();

    final runs = <Map<String, Object?>>[];
    for (final characters in const [10000, 100000, 1000000]) {
      final reading = _reading(characters);
      final beforeFrames = timings.length;
      final beforeRss = ProcessInfo.currentRss;
      final clock = Stopwatch()..start();

      await tester.pumpWidget(_app(reading));
      await tester.pumpAndSettle();
      clock.stop();
      await Future<void>.delayed(const Duration(milliseconds: 180));
      await tester.pump();

      final horizontal = find.byWidgetPredicate(
        (widget) =>
            widget is SingleChildScrollView &&
            widget.scrollDirection == Axis.horizontal,
      );
      final position = tester
          .widget<SingleChildScrollView>(horizontal)
          .controller!
          .position;
      final renderedCharacters = _renderedCharacters();
      final maximumExtent = position.maxScrollExtent;
      position.jumpTo(maximumExtent * 0.5);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await Future<void>.delayed(const Duration(milliseconds: 180));
      await tester.pump();
      final middleRanges = _mountedColumnRanges();
      runs.add({
        'source_characters': characters,
        'rendered_characters': renderedCharacters,
        'middle_rendered_characters': _renderedCharacters(),
        'middle_column_start': middleRanges.isEmpty
            ? null
            : middleRanges.map((range) => range.start).reduce(math.min),
        'middle_column_end': middleRanges.isEmpty
            ? null
            : middleRanges.map((range) => range.end).reduce(math.max),
        'open_wall_us': clock.elapsedMicroseconds,
        'maximum_horizontal_scroll_extent': maximumExtent,
        'rss_delta_bytes': ProcessInfo.currentRss - beforeRss,
        'frames': _frameSummary(
          timings.skip(beforeFrames).toList(growable: false),
        ),
      });

      expect(maximumExtent, greaterThan(0));
      expect(renderedCharacters, lessThanOrEqualTo(32768));
      expect(_renderedCharacters(), lessThanOrEqualTo(32768));
      if (characters >= 32768) {
        expect(middleRanges, isNotEmpty);
        expect(middleRanges.first.start, greaterThan(characters * 0.4));
      }
      expect(tester.takeException(), isNull);
    }

    binding.reportData = {
      'benchmark': 'atomic_code_line_scaling',
      'mode': 'profile',
      'viewport_logical_pixels': {'width': 1280, 'height': 820},
      'runs': runs,
    };
  });
}

int _renderedCharacters() => find
    .descendant(
      of: find.byKey(const ValueKey('code-source')),
      matching: find.byType(RichText),
    )
    .evaluate()
    .map(
      (element) =>
          (element.renderObject! as RenderParagraph).text.toPlainText().length,
    )
    .fold(0, (total, length) => total + length);

List<({int start, int end})> _mountedColumnRanges() => [
  for (final element in find.byWidgetPredicate((widget) {
    final key = widget.key;
    return key is ValueKey<String> && key.value.startsWith('code-column-');
  }).evaluate())
    _columnRange((element.widget.key! as ValueKey<String>).value),
];

({int start, int end}) _columnRange(String key) {
  final parts = key.split('-');
  return (start: int.parse(parts[2]), end: int.parse(parts[3]));
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

DocumentReading _reading(int characters) {
  const unit = 'final_value += input_value; ';
  final source =
      (StringBuffer()
            ..writeAll(List.filled((characters / unit.length).ceil(), unit)))
          .toString()
          .substring(0, characters);
  final documentSource = '```dart\n$source\n```';
  return DocumentReading(
    document: Document(
      id: DocumentId(
        const LibraryRootId('atomic-line-benchmark'),
        'line-$characters.md',
      ),
      content: documentSource,
      title: 'Atomic line benchmark',
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
