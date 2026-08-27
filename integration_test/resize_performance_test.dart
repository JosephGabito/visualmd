import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:visualmd/api/render/document_view.dart';
import 'package:visualmd/api/theme/library_theme.dart';
import 'package:visualmd/api/widgets/reading_pane.dart';
import 'package:visualmd/application/ports/document_viewport_geometry.dart';
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

/// Exposes how much document geometry a continuous window resize visits.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('resize exposes geometry invalidation scaling', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final runs = <Map<String, Object?>>[];

    for (final blocks in const [100, 1000, 5000]) {
      final geometry = _CountingGeometryFactory();
      tester.view.physicalSize = const Size(1000, 700);
      await tester.pumpWidget(_app(_reading(blocks), geometry));
      await tester.pumpAndSettle();
      geometry.relayoutExtentVisits = 0;
      geometry.relayoutCalls = 0;
      final beforeRss = ProcessInfo.currentRss;
      final clock = Stopwatch()..start();

      const widths = [720.0, 980.0, 740.0, 960.0, 760.0, 940.0];
      for (final width in widths) {
        tester.view.physicalSize = Size(width, 700);
        await tester.pump();
      }
      clock.stop();

      runs.add({
        'document_blocks': blocks,
        'resize_steps': widths.length,
        'relayout_calls': geometry.relayoutCalls,
        'relayout_extent_visits': geometry.relayoutExtentVisits,
        'resize_wall_us': clock.elapsedMicroseconds,
        'mounted_paragraphs': find.byType(Paragraph).evaluate().length,
        'retained_paragraphs': find
            .byType(Paragraph, skipOffstage: false)
            .evaluate()
            .length,
        'rss_delta_bytes': ProcessInfo.currentRss - beforeRss,
      });
      expect(geometry.relayoutCalls, widths.length);
      expect(
        geometry.relayoutExtentVisits,
        0,
        reason: 'an interactive resize must not visit offscreen block extents',
      );
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }

    binding.reportData = {
      'benchmark': 'continuous_resize_scaling',
      'mode': 'profile',
      'runs': runs,
    };
  });
}

Widget _app(
  DocumentReading reading,
  DocumentViewportGeometryFactory geometry,
) => MaterialApp(
  theme: libraryTheme(BuiltInThemes.paper),
  home: Scaffold(
    body: ReadingPane(
      reading: reading,
      scale: ReadingScale.comfortable,
      viewportGeometry: geometry,
      onLink: (_) {},
      onActiveHeadingChanged: (_) {},
    ),
  ),
);

DocumentReading _reading(int count) {
  final id = DocumentId(const LibraryRootId('resize'), 'resize.md');
  final entries = List<DocumentBlock>.unmodifiable([
    for (var index = 0; index < count; index++)
      DocumentBlock(
        id: DocumentBlockId('paragraph-$index'),
        revision: 0,
        block: ParagraphBlock([
          TextRun(
            'Paragraph $index has enough stable text to wrap differently '
            'as the reading window changes width.',
          ),
        ]),
      ),
  ]);
  final content = DocumentContent.revisioned(entries);
  return DocumentReading(
    document: Document(id: id, content: content.text, title: 'Resize'),
    source: content.text,
    outline: DocumentOutline.parse(''),
    content: content,
  );
}

final class _CountingGeometryFactory
    implements DocumentViewportGeometryFactory {
  static const _delegate = QuietDocumentViewportGeometryFactory();

  int relayoutCalls = 0;
  int relayoutExtentVisits = 0;

  @override
  DocumentViewportGeometry create({int layoutRevision = 0}) =>
      _CountingGeometry(this, _delegate.create(layoutRevision: layoutRevision));

  @override
  FrozenDocumentScrollMetrics freezeMetrics({
    required double contentExtent,
    required double viewportExtent,
  }) => _delegate.freezeMetrics(
    contentExtent: contentExtent,
    viewportExtent: viewportExtent,
  );
}

final class _CountingGeometry implements DocumentViewportGeometry {
  final _CountingGeometryFactory owner;
  final DocumentViewportGeometry delegate;

  const _CountingGeometry(this.owner, this.delegate);

  @override
  int get layoutRevision => delegate.layoutRevision;

  @override
  int get length => delegate.length;

  @override
  double get totalExtent => delegate.totalExtent;

  @override
  void appendAll(Iterable<DocumentExtentSeed> seeds) =>
      delegate.appendAll(seeds);

  @override
  DocumentBlockId? blockAtOffset(double offset) =>
      delegate.blockAtOffset(offset);

  @override
  FrozenDocumentScrollMetrics freeze({required double viewportExtent}) =>
      delegate.freeze(viewportExtent: viewportExtent);

  @override
  int indexOf(DocumentBlockId id) => delegate.indexOf(id);

  @override
  double leadingOffsetOf(DocumentBlockId id) => delegate.leadingOffsetOf(id);

  @override
  DocumentExtentCorrection? measure({
    required DocumentBlockId id,
    required int itemRevision,
    required int layoutRevision,
    required double extent,
    DocumentBlockId? anchor,
  }) => delegate.measure(
    id: id,
    itemRevision: itemRevision,
    layoutRevision: layoutRevision,
    extent: extent,
    anchor: anchor,
  );

  @override
  DocumentExtentCorrection relayout({
    required int revision,
    required Iterable<double> estimatedExtents,
    DocumentBlockId? anchor,
  }) {
    owner.relayoutCalls++;
    return delegate.relayout(
      revision: revision,
      estimatedExtents: estimatedExtents.map((extent) {
        owner.relayoutExtentVisits++;
        return extent;
      }),
      anchor: anchor,
    );
  }

  @override
  DocumentExtentCorrection scaleRelayout({
    required int revision,
    required double scale,
    DocumentBlockId? anchor,
  }) {
    owner.relayoutCalls++;
    return delegate.scaleRelayout(
      revision: revision,
      scale: scale,
      anchor: anchor,
    );
  }

  @override
  DocumentExtentCorrection replaceTail({
    required int start,
    required Iterable<DocumentExtentSeed> seeds,
    DocumentBlockId? anchor,
  }) => delegate.replaceTail(start: start, seeds: seeds, anchor: anchor);

  @override
  DocumentExtentCorrection reset(
    Iterable<DocumentExtentSeed> seeds, {
    required int layoutRevision,
    DocumentBlockId? anchor,
  }) => delegate.reset(seeds, layoutRevision: layoutRevision, anchor: anchor);

  @override
  DocumentExtentCorrection revise({
    required DocumentExtentSeed seed,
    DocumentBlockId? anchor,
  }) => delegate.revise(seed: seed, anchor: anchor);
}
