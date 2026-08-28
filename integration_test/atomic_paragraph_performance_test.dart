import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:visualmd/api/render/document_view.dart';
import 'package:visualmd/api/theme/library_theme.dart';
import 'package:visualmd/api/widgets/reading_pane.dart';
import 'package:visualmd/api/widgets/windowed_paragraph.dart';
import 'package:visualmd/application/use_cases/read_document.dart';
import 'package:visualmd/domain/library/document.dart';
import 'package:visualmd/domain/library/document_id.dart';
import 'package:visualmd/domain/library/library_root_id.dart';
import 'package:visualmd/domain/reading/content/block.dart';
import 'package:visualmd/domain/reading/content/document_content.dart';
import 'package:visualmd/domain/reading/content/inline.dart';
import 'package:visualmd/domain/reading/document_outline.dart';
import 'package:visualmd/infrastructure/viewport/quiet_document_viewport_geometry.dart';
import 'package:visualmd/presentation/theme/built_in_themes.dart';
import 'package:visualmd/presentation/theme/reading_scale.dart';

/// Measures the atomic-block failure mode most likely during AI generation.
///
/// A paragraph has no authored line boundaries. This journey measures the
/// eager small-block path beside provisional line windowing at pathological
/// sizes, including a deep seek through the outer document viewport.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('one provisional paragraph exposes its complete shaping cost', (
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

      final scrollable = find.descendant(
        of: find.byType(CustomScrollView),
        matching: find.byType(Scrollable),
      );
      final position = tester.state<ScrollableState>(scrollable.first).position;
      final mountedCharacters = _mountedCharacters();
      final windowed = find
          .byType(WindowedProvisionalParagraph)
          .evaluate()
          .isNotEmpty;
      final seekFramesStart = timings.length;
      final seekClock = Stopwatch()..start();
      position.jumpTo(position.maxScrollExtent * 0.5);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      seekClock.stop();
      await Future<void>.delayed(const Duration(milliseconds: 180));
      await tester.pump();
      final seekFrames = _frameSummary(
        timings.skip(seekFramesStart).toList(growable: false),
      );

      const suffix = ' One bounded streamed sentence arrives at the tail.';
      final pixelsBeforeAppend = position.pixels;
      final appendFramesStart = timings.length;
      final appendClock = Stopwatch()..start();
      await tester.pumpWidget(
        _app(
          _reading(
            characters,
            suffix: suffix,
            append: BlockTextAppend(baseRevision: characters, text: suffix),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      appendClock.stop();
      await Future<void>.delayed(const Duration(milliseconds: 180));
      await tester.pump();
      final pixelsAfterAppend = position.pixels;
      final appendFrames = _frameSummary(
        timings.skip(appendFramesStart).toList(growable: false),
      );

      runs.add({
        'source_characters': characters,
        'mounted_characters': mountedCharacters,
        'windowed': windowed,
        'open_wall_us': clock.elapsedMicroseconds,
        'maximum_scroll_extent': position.maxScrollExtent,
        'rss_delta_bytes': ProcessInfo.currentRss - beforeRss,
        'middle_seek_wall_us': seekClock.elapsedMicroseconds,
        'middle_seek_frames': seekFrames,
        'append_wall_us': appendClock.elapsedMicroseconds,
        'append_scroll_delta': pixelsAfterAppend - pixelsBeforeAppend,
        'append_frames': appendFrames,
        'frames': _frameSummary(
          timings.skip(beforeFrames).toList(growable: false),
        ),
      });

      expect(mountedCharacters, windowed ? lessThan(5000) : equals(characters));
      expect(position.maxScrollExtent, greaterThan(0));
      expect(pixelsAfterAppend, pixelsBeforeAppend);
      expect(tester.takeException(), isNull);
    }

    binding.reportData = {
      'benchmark': 'atomic_paragraph_scaling',
      'mode': 'profile',
      'viewport_logical_pixels': {'width': 1280, 'height': 820},
      'runs': runs,
    };
  });
}

int _mountedCharacters() => find
    .descendant(
      of: find.byType(Paragraph).evaluate().isNotEmpty
          ? find.byType(Paragraph)
          : find.byType(WindowedProvisionalParagraph),
      matching: find.byType(RichText),
    )
    .evaluate()
    .map(
      (element) =>
          (element.renderObject! as RenderParagraph).text.toPlainText().length,
    )
    .fold(0, (total, length) => total + length);

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

DocumentReading _reading(
  int characters, {
  String suffix = '',
  BlockTextAppend? append,
}) {
  const unit =
      'Generated prose keeps extending without an authored paragraph break. ';
  final prefix =
      (StringBuffer()
            ..writeAll(List.filled((characters / unit.length).ceil(), unit)))
          .toString()
          .substring(0, characters);
  final source = '$prefix$suffix';
  final id = DocumentId(
    const LibraryRootId('atomic-paragraph-benchmark'),
    'paragraph.md',
  );
  return DocumentReading(
    document: Document(id: id, content: source, title: 'Atomic paragraph'),
    source: source,
    outline: DocumentOutline.parse(''),
    content: DocumentContent.revisioned([
      DocumentBlock(
        id: const DocumentBlockId('provisional-paragraph'),
        revision: characters + (append == null ? 0 : 1),
        commitment: BlockCommitment.provisional,
        block: ParagraphBlock([TextRun(source)]),
        textAppend: append,
      ),
    ]),
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
    'build_p50_us': _percentile(builds, 0.50),
    'build_p90_us': _percentile(builds, 0.90),
    'build_p99_us': _percentile(builds, 0.99),
    'build_worst_us': builds.isEmpty ? 0 : builds.reduce(math.max),
    'total_p90_us': _percentile(totals, 0.90),
    'total_p99_us': _percentile(totals, 0.99),
    'total_worst_us': totals.isEmpty ? 0 : totals.reduce(math.max),
  };
}

int _percentile(List<int> values, double percentile) {
  if (values.isEmpty) return 0;
  final sorted = [...values]..sort();
  final index = ((sorted.length - 1) * percentile).round();
  return sorted[index];
}
