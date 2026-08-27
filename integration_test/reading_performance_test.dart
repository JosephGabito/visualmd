import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:visualmd/api/render/document_view.dart';
import 'package:visualmd/api/theme/library_theme.dart';
import 'package:visualmd/api/widgets/reading_pane.dart';
import 'package:visualmd/application/generated_document_stream.dart';
import 'package:visualmd/application/use_cases/read_document.dart';
import 'package:visualmd/domain/library/document.dart';
import 'package:visualmd/domain/library/document_id.dart';
import 'package:visualmd/domain/library/library_root_id.dart';
import 'package:visualmd/domain/reading/content/block.dart';
import 'package:visualmd/domain/reading/content/document_content.dart';
import 'package:visualmd/domain/reading/content/inline.dart';
import 'package:visualmd/domain/reading/document_outline.dart';
import 'package:visualmd/infrastructure/markdown/markdown_document_parser.dart';
import 'package:visualmd/infrastructure/viewport/quiet_document_viewport_geometry.dart';
import 'package:visualmd/presentation/theme/built_in_themes.dart';
import 'package:visualmd/presentation/theme/reading_scale.dart';

/// A native, profile-mode macrobenchmark of the real reading surface.
///
/// The corpus is already parsed so this measures the reader's build, layout,
/// paint, scrolling, and update costs independently of Markdown parsing. The
/// sizes deliberately vary by orders of magnitude: a viewport-bounded reader
/// should mount roughly the same number of paragraphs at every size.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('reader work stays bounded by the viewport', (tester) async {
    tester.view.physicalSize = const Size(1280, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final timings = <FrameTiming>[];
    void collect(List<FrameTiming> batch) => timings.addAll(batch);
    SchedulerBinding.instance.addTimingsCallback(collect);
    addTearDown(() => SchedulerBinding.instance.removeTimingsCallback(collect));

    final runs = <Map<String, Object?>>[];
    for (final blockCount in const [100, 1000, 5000]) {
      final reading = _reading(blockCount);
      final navigationIndexPasses = <int>[];
      final renderIndexPasses = <int>[];
      final beforeFrames = timings.length;
      final beforeRss = ProcessInfo.currentRss;
      final buildClock = Stopwatch()..start();

      await tester.pumpWidget(
        _app(reading, navigationIndexPasses, renderIndexPasses),
      );
      await tester.pumpAndSettle();
      buildClock.stop();

      // Frame timings are delivered in batches in profile mode. A short real
      // drain keeps each journey's samples attached to the journey that made
      // them without polluting the measured wall-clock duration.
      await Future<void>.delayed(const Duration(milliseconds: 180));
      await tester.pump();
      final buildFrames = timings.skip(beforeFrames).toList(growable: false);
      final mountedAfterBuild = find.byType(Paragraph).evaluate().length;

      final scrollBefore = timings.length;
      final scrollClock = Stopwatch()..start();
      final scrollable = find.byType(Scrollable).first;
      await tester.drag(scrollable, const Offset(0, -2400));
      await tester.pumpAndSettle();
      scrollClock.stop();
      await Future<void>.delayed(const Duration(milliseconds: 180));
      await tester.pump();
      final scrollFrames = timings.skip(scrollBefore).toList(growable: false);

      final appended = _appendOne(reading, blockCount);
      final appendBefore = timings.length;
      final appendClock = Stopwatch()..start();
      await tester.pumpWidget(
        _app(appended, navigationIndexPasses, renderIndexPasses),
      );
      await tester.pumpAndSettle();
      appendClock.stop();
      await Future<void>.delayed(const Duration(milliseconds: 180));
      await tester.pump();
      final appendFrames = timings.skip(appendBefore).toList(growable: false);

      final concurrentBefore = timings.length;
      final concurrentClock = Stopwatch()..start();
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      final offsetBeforeConcurrent = position.pixels;
      await tester.fling(
        find.byType(CustomScrollView),
        const Offset(0, -1200),
        3000,
      );
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pumpWidget(
        _app(
          _appendOne(appended, blockCount + 1),
          navigationIndexPasses,
          renderIndexPasses,
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pumpAndSettle();
      concurrentClock.stop();
      await Future<void>.delayed(const Duration(milliseconds: 180));
      await tester.pump();
      final concurrentFrames = timings
          .skip(concurrentBefore)
          .toList(growable: false);

      runs.add({
        'blocks': blockCount,
        'mounted_paragraphs': mountedAfterBuild,
        'build_wall_us': buildClock.elapsedMicroseconds,
        'scroll_wall_us': scrollClock.elapsedMicroseconds,
        'append_one_wall_us': appendClock.elapsedMicroseconds,
        'stream_while_scroll_wall_us': concurrentClock.elapsedMicroseconds,
        'stream_while_scroll_offset_delta':
            position.pixels - offsetBeforeConcurrent,
        'navigation_index_passes': navigationIndexPasses,
        'render_index_passes': renderIndexPasses,
        'rss_delta_bytes': ProcessInfo.currentRss - beforeRss,
        'build_frames': _frameSummary(buildFrames),
        'scroll_frames': _frameSummary(scrollFrames),
        'append_frames': _frameSummary(appendFrames),
        'stream_while_scroll_frames': _frameSummary(concurrentFrames),
      });

      expect(mountedAfterBuild, greaterThan(0));
      expect(position.pixels, greaterThan(offsetBeforeConcurrent));
      expect(tester.takeException(), isNull);
    }

    final streaming = await _benchmarkGeneratedStream(tester, timings);

    binding.reportData = {
      'benchmark': 'reading_surface_scaling',
      'mode': 'profile',
      'viewport_logical_pixels': {'width': 1280, 'height': 820},
      'runs': runs,
      'generated_stream': streaming,
    };
  });
}

Future<Map<String, Object?>> _benchmarkGeneratedStream(
  WidgetTester tester,
  List<FrameTiming> timings,
) async {
  final documentId = DocumentId(
    const LibraryRootId('benchmark'),
    'generated.md',
  );
  const streamId = DocumentStreamId('benchmark-generation');
  final session = GeneratedDocumentStreamSession(
    documentId: documentId,
    streamId: streamId,
    parser: const MarkdownDocumentParser(),
    maxLatency: Duration.zero,
    maxBatchCharacters: 1,
  );
  GeneratedDocumentRevision? latest;
  final subscription = session.revisions.listen((revision) {
    latest = revision;
  });
  addTearDown(() async {
    await session.cancel();
    await subscription.cancel();
  });

  final initialSource = List.generate(
    5000,
    (index) =>
        'Paragraph $index keeps the committed prefix large while the parser '
        'and reader work only on the generated tail.\n\n',
    growable: false,
  ).join();
  final initialClock = Stopwatch()..start();
  expect(
    session.accept(
      GeneratedDocumentDelta(
        streamId: streamId,
        sequence: 0,
        sourceOffset: 0,
        source: initialSource,
      ),
    ),
    isTrue,
  );
  initialClock.stop();
  final initial = latest!;
  final navigationIndexPasses = <int>[];
  final renderIndexPasses = <int>[];
  await tester.pumpWidget(
    _app(_streamReading(initial), navigationIndexPasses, renderIndexPasses),
  );
  await tester.pumpAndSettle();
  final initialNavigationVisits = [...navigationIndexPasses];
  final initialRenderVisits = [...renderIndexPasses];
  navigationIndexPasses.clear();
  renderIndexPasses.clear();

  await tester.drag(find.byType(CustomScrollView), const Offset(0, -8000));
  await tester.pumpAndSettle();
  final position = tester
      .state<ScrollableState>(find.byType(Scrollable).first)
      .position;
  final offsetBefore = position.pixels;
  final beforeRss = ProcessInfo.currentRss;
  final beforeFrames = timings.length;
  await tester.fling(
    find.byType(CustomScrollView),
    const Offset(0, -2400),
    8000,
  );
  await tester.pump(const Duration(milliseconds: 8));

  final updateWallMicroseconds = <int>[];
  final acceptWallMicroseconds = <int>[];
  final parsedCharacters = <int>[];
  var sequence = 1;
  for (var paragraph = 0; paragraph < 20; paragraph++) {
    final pieces = [
      'Streamed paragraph $paragraph begins with a bounded provisional tail',
      ' and finishes without touching the five-thousand-block prefix.',
      '\n\n',
    ];
    for (final piece in pieces) {
      latest = null;
      final updateClock = Stopwatch()..start();
      final acceptClock = Stopwatch()..start();
      expect(
        session.accept(
          GeneratedDocumentDelta(
            streamId: streamId,
            sequence: sequence++,
            sourceOffset: session.acceptedSourceLength,
            source: piece,
          ),
        ),
        isTrue,
      );
      acceptClock.stop();
      acceptWallMicroseconds.add(acceptClock.elapsedMicroseconds);
      final revision = latest!;
      parsedCharacters.add(revision.parsedSourceCharacters);
      await tester.pumpWidget(
        _app(
          _streamReading(revision),
          navigationIndexPasses,
          renderIndexPasses,
        ),
      );
      await tester.pump(const Duration(milliseconds: 8));
      updateClock.stop();
      updateWallMicroseconds.add(updateClock.elapsedMicroseconds);
      expect(tester.takeException(), isNull);
    }
  }
  await tester.pumpAndSettle();
  await Future<void>.delayed(const Duration(milliseconds: 180));
  await tester.pump();
  final frames = timings.skip(beforeFrames).toList(growable: false);
  final mounted = find.byType(Paragraph).evaluate().length;

  expect(initial.content.entries, hasLength(5000));
  expect(initialNavigationVisits, [5000]);
  expect(initialRenderVisits, [5000]);
  expect(navigationIndexPasses, everyElement(1));
  expect(renderIndexPasses, everyElement(1));
  expect(parsedCharacters.reduce(math.max), lessThan(256));
  expect(position.pixels, greaterThan(offsetBefore));
  expect(mounted, lessThan(40));

  return {
    'committed_prefix_blocks': 5000,
    'streamed_paragraphs': 20,
    'published_revisions': updateWallMicroseconds.length,
    'initial_parse_wall_us': initialClock.elapsedMicroseconds,
    'initial_navigation_index_passes': initialNavigationVisits,
    'initial_render_index_passes': initialRenderVisits,
    'update_navigation_index_passes': navigationIndexPasses,
    'update_render_index_passes': renderIndexPasses,
    'parsed_characters_per_revision': parsedCharacters,
    'parsed_characters_worst': parsedCharacters.reduce(math.max),
    'accept_parse_publish_p50_us': _percentile(acceptWallMicroseconds, 0.50),
    'accept_parse_publish_p90_us': _percentile(acceptWallMicroseconds, 0.90),
    'accept_parse_publish_worst_us': acceptWallMicroseconds.reduce(math.max),
    'harness_revision_wall_p50_us': _percentile(updateWallMicroseconds, 0.50),
    'harness_revision_wall_p90_us': _percentile(updateWallMicroseconds, 0.90),
    'harness_revision_wall_worst_us': updateWallMicroseconds.reduce(math.max),
    'scroll_offset_delta': position.pixels - offsetBefore,
    'mounted_paragraphs': mounted,
    'rss_delta_bytes': ProcessInfo.currentRss - beforeRss,
    'frames': _frameSummary(frames),
  };
}

DocumentReading _streamReading(GeneratedDocumentRevision revision) {
  final source = 'generated revision ${revision.content.revision}';
  return DocumentReading(
    document: Document(
      id: revision.documentId,
      content: source,
      title: 'Generated benchmark',
    ),
    source: source,
    // Outline projection is benchmarked separately once its suffix contract
    // exists. This journey isolates source, parse, content, geometry, and UI.
    outline: DocumentOutline.parse(''),
    content: revision.content,
  );
}

Widget _app(
  DocumentReading reading,
  List<int> navigationIndexPasses,
  List<int> renderIndexPasses,
) => MaterialApp(
  theme: libraryTheme(BuiltInThemes.paper),
  home: Scaffold(
    body: ReadingPane(
      reading: reading,
      scale: ReadingScale.comfortable,
      viewportGeometry: const QuietDocumentViewportGeometryFactory(),
      onLink: (_) {},
      onActiveHeadingChanged: (_) {},
      debugOnNavigationBlocksIndexed: navigationIndexPasses.add,
      debugOnRenderBlocksIndexed: renderIndexPasses.add,
    ),
  ),
);

DocumentReading _reading(int count, {DocumentId? documentId}) {
  final id =
      documentId ?? DocumentId(const LibraryRootId('benchmark'), 'load.md');
  final entries = List<DocumentBlock>.unmodifiable([
    DocumentBlock(
      id: DocumentBlockId('heading'),
      revision: 0,
      block: HeadingBlock(
        level: 1,
        content: [TextRun('Rendering benchmark')],
        anchor: 'rendering-benchmark',
      ),
    ),
    for (var index = 0; index < count; index++)
      DocumentBlock(
        id: DocumentBlockId('paragraph-$index'),
        revision: 0,
        block: ParagraphBlock([
          TextRun(
            'Paragraph $index keeps the same shape so changes in timing come '
            'from document length rather than unusually expensive content.',
          ),
        ]),
      ),
  ]);
  final source = 'benchmark revision 0 with $count paragraphs';
  return DocumentReading(
    document: Document(id: id, content: source, title: 'Rendering benchmark'),
    source: source,
    outline: DocumentOutline.parse('# Rendering benchmark'),
    content: DocumentContent.revisioned(entries),
  );
}

DocumentReading _appendOne(DocumentReading reading, int paragraphCount) {
  final tail = DocumentBlock(
    id: DocumentBlockId('paragraph-$paragraphCount'),
    revision: 1,
    commitment: BlockCommitment.provisional,
    block: ParagraphBlock([
      TextRun(
        'Paragraph $paragraphCount keeps the same shape so changes in timing '
        'come from document length rather than unusually expensive content.',
      ),
    ]),
  );
  final content = reading.content.apply(
    DocumentMutation.append(
      baseRevision: reading.content.revision,
      revision: reading.content.revision + 1,
      index: reading.content.entries.length,
      blocks: [tail],
    ),
  );
  final source = 'benchmark revision ${content.revision}';
  return DocumentReading(
    document: Document(
      id: reading.document.id,
      content: source,
      title: reading.document.title,
    ),
    source: source,
    outline: reading.outline,
    content: content,
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
