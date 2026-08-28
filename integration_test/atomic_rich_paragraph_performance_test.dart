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
import 'package:visualmd/api/widgets/windowed_rich_paragraph.dart';
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

/// Measures the remaining atomic paragraph path with ordinary inline marks.
///
/// Generated Markdown commonly keeps emphasis, code and links inside a still-
/// open paragraph. One such run currently prevents line windowing, so this
/// fixture records the failure before changing its rendering contract.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('one rich paragraph exposes its complete span and shaping cost', (
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
      final runCount = (reading.content.entries.single.block as ParagraphBlock)
          .content
          .length;
      final beforeFrames = timings.length;
      final beforeRss = ProcessInfo.currentRss;
      final clock = Stopwatch()..start();
      var indexedCharacters = 0;
      final indexSteps = <Duration>[];

      await tester.pumpWidget(
        _app(
          reading,
          onSourceIndexed: (value) => indexedCharacters = value,
          onIndexStep: (_, elapsed) => indexSteps.add(elapsed),
        ),
      );
      await tester.pumpAndSettle();
      var indexingPumps = 0;
      while (reading.source.length >= 32768 &&
          indexedCharacters < reading.source.length) {
        await tester.pump(const Duration(milliseconds: 1));
        indexingPumps++;
        expect(indexingPumps, lessThan(400));
      }
      clock.stop();
      await Future<void>.delayed(const Duration(milliseconds: 180));
      await tester.pump();
      final openFrames = _frameSummary(
        timings.skip(beforeFrames).toList(growable: false),
      );

      final scrollable = find.descendant(
        of: find.byType(CustomScrollView),
        matching: find.byType(Scrollable),
      );
      final position = tester.state<ScrollableState>(scrollable.first).position;
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

      final mountedCharacters = _mountedCharacters();
      final windowed = find.byType(WindowedRichParagraph).evaluate().isNotEmpty;

      const suffix = <Inline>[
        TextRun(' A streamed '),
        MarkedRun(InlineMark.strong, [TextRun('styled')]),
        TextRun(' suffix with '),
        CodeRun('inline_code'),
        TextRun(' arrives.'),
      ];
      final appended = _reading(
        characters,
        suffix: suffix,
        inlineAppend: BlockInlineAppend(
          baseRevision: reading.content.entries.single.revision,
          runs: suffix,
        ),
      );
      final pixelsBeforeAppend = position.pixels;
      final appendFramesStart = timings.length;
      final appendClock = Stopwatch()..start();
      var appendedIndexedCharacters = 0;
      final appendIndexSteps = <Duration>[];
      await tester.pumpWidget(
        _app(
          appended,
          onSourceIndexed: (value) => appendedIndexedCharacters = value,
          onIndexStep: (_, elapsed) => appendIndexSteps.add(elapsed),
        ),
      );
      await tester.pumpAndSettle();
      var appendIndexingPumps = 0;
      while (windowed && appendedIndexedCharacters == 0) {
        await tester.pump(const Duration(milliseconds: 1));
        appendIndexingPumps++;
        expect(appendIndexingPumps, lessThan(400));
      }
      appendClock.stop();
      await Future<void>.delayed(const Duration(milliseconds: 180));
      await tester.pump();
      final appendFrames = _frameSummary(
        timings.skip(appendFramesStart).toList(growable: false),
      );
      final pixelsAfterAppend = position.pixels;

      runs.add({
        'source_characters': reading.source.length,
        'inline_runs': runCount,
        'mounted_characters': mountedCharacters,
        'windowed': windowed,
        'indexing_pumps': indexingPumps,
        'index_step_worst_us': indexSteps.isEmpty
            ? 0
            : indexSteps.map((step) => step.inMicroseconds).reduce(math.max),
        'open_wall_us': clock.elapsedMicroseconds,
        'open_frames': openFrames,
        'middle_seek_wall_us': seekClock.elapsedMicroseconds,
        'middle_seek_frames': seekFrames,
        'append_characters': appended.source.length - reading.source.length,
        'append_indexing_pumps': appendIndexingPumps,
        'append_index_step_worst_us': appendIndexSteps.isEmpty
            ? 0
            : appendIndexSteps
                  .map((step) => step.inMicroseconds)
                  .reduce(math.max),
        'append_wall_us': appendClock.elapsedMicroseconds,
        'append_frames': appendFrames,
        'append_mounted_characters': _mountedCharacters(),
        'append_scroll_delta': pixelsAfterAppend - pixelsBeforeAppend,
        'maximum_scroll_extent': position.maxScrollExtent,
        'rss_delta_bytes': ProcessInfo.currentRss - beforeRss,
      });

      expect(
        mountedCharacters,
        windowed ? lessThan(5000) : reading.source.length,
      );
      expect(position.maxScrollExtent, greaterThan(0));
      expect(pixelsAfterAppend, pixelsBeforeAppend);
      expect(tester.takeException(), isNull);
    }

    binding.reportData = {
      'benchmark': 'atomic_rich_paragraph_scaling',
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
          : find.byType(WindowedPlainParagraph),
      matching: find.byType(RichText),
    )
    .evaluate()
    .map(
      (element) =>
          (element.renderObject! as RenderParagraph).text.toPlainText().length,
    )
    .fold(0, (total, length) => total + length);

Widget _app(
  DocumentReading reading, {
  ValueChanged<int>? onSourceIndexed,
  ParagraphIndexStepObserver? onIndexStep,
}) => MaterialApp(
  theme: libraryTheme(BuiltInThemes.paper),
  home: Scaffold(
    body: ReadingPane(
      reading: reading,
      scale: ReadingScale.comfortable,
      viewportGeometry: const QuietDocumentViewportGeometryFactory(),
      onLink: (_) {},
      onActiveHeadingChanged: (_) {},
      debugOnParagraphCodeUnitsIndexed: onSourceIndexed,
      debugOnParagraphInitialIndexStep: onIndexStep,
    ),
  ),
);

DocumentReading _reading(
  int minimumCharacters, {
  List<Inline> suffix = const [],
  BlockInlineAppend? inlineAppend,
}) {
  final runs = [..._richRuns(minimumCharacters), ...suffix];
  final source = runs.map((run) => run.text).join();
  final id = DocumentId(
    const LibraryRootId('atomic-rich-paragraph-benchmark'),
    'paragraph.md',
  );
  return DocumentReading(
    document: Document(id: id, content: source, title: 'Atomic rich paragraph'),
    source: source,
    outline: DocumentOutline.parse(''),
    content: DocumentContent.revisioned([
      DocumentBlock(
        id: const DocumentBlockId('provisional-rich-paragraph'),
        revision: source.length,
        commitment: BlockCommitment.provisional,
        block: ParagraphBlock(runs),
        inlineAppend: inlineAppend,
      ),
    ]),
  );
}

List<Inline> _richRuns(int minimumCharacters) {
  const unit = <Inline>[
    TextRun('Generated '),
    MarkedRun(InlineMark.strong, [TextRun('bold')]),
    TextRun(' prose with '),
    CodeRun('inline_code'),
    TextRun(' and '),
    LinkRun(href: 'https://example.com', children: [TextRun('a link')]),
    TextRun(' keeps extending. '),
  ];
  final runs = <Inline>[];
  var characters = 0;
  while (characters < minimumCharacters) {
    runs.addAll(unit);
    characters += unit.fold(0, (total, run) => total + run.text.length);
  }
  return runs;
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
