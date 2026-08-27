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
/// A paragraph has no authored line boundaries. Flutter therefore receives it
/// as one shaped object even when the top-level document is a lazy sliver. This
/// profile journey establishes that slope before provisional line windowing.
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
      final renderedCharacters = _renderedCharacters();
      final seekFramesStart = timings.length;
      final seekClock = Stopwatch()..start();
      position.jumpTo(position.maxScrollExtent * 0.5);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      seekClock.stop();
      await Future<void>.delayed(const Duration(milliseconds: 180));
      await tester.pump();

      runs.add({
        'source_characters': characters,
        'rendered_characters': renderedCharacters,
        'open_wall_us': clock.elapsedMicroseconds,
        'maximum_scroll_extent': position.maxScrollExtent,
        'rss_delta_bytes': ProcessInfo.currentRss - beforeRss,
        'middle_seek_wall_us': seekClock.elapsedMicroseconds,
        'middle_seek_frames': _frameSummary(
          timings.skip(seekFramesStart).toList(growable: false),
        ),
        'frames': _frameSummary(
          timings.skip(beforeFrames).toList(growable: false),
        ),
      });

      expect(renderedCharacters, characters);
      expect(position.maxScrollExtent, greaterThan(0));
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

int _renderedCharacters() => find
    .descendant(of: find.byType(Paragraph), matching: find.byType(RichText))
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

DocumentReading _reading(int characters) {
  const unit =
      'Generated prose keeps extending without an authored paragraph break. ';
  final source =
      (StringBuffer()
            ..writeAll(List.filled((characters / unit.length).ceil(), unit)))
          .toString()
          .substring(0, characters);
  final id = DocumentId(
    const LibraryRootId('atomic-paragraph-benchmark'),
    'paragraph-$characters.md',
  );
  return DocumentReading(
    document: Document(id: id, content: source, title: 'Atomic paragraph'),
    source: source,
    outline: DocumentOutline.parse(''),
    content: DocumentContent.revisioned([
      DocumentBlock(
        id: const DocumentBlockId('provisional-paragraph'),
        revision: characters,
        commitment: BlockCommitment.provisional,
        block: ParagraphBlock([TextRun(source)]),
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
