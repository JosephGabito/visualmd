import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/application/ports/document_viewport_geometry.dart';
import 'package:visualmd/domain/reading/content/document_content.dart';
import 'package:visualmd/infrastructure/viewport/quiet_document_viewport_geometry.dart';

void main() {
  const factory = QuietDocumentViewportGeometryFactory();

  test('the adapter preserves anchor and thumb invariants across rings', () {
    final geometry = factory.create()
      ..appendAll([
        const DocumentExtentSeed(
          id: DocumentBlockId('a'),
          revision: 0,
          estimatedExtent: 100,
        ),
        const DocumentExtentSeed(
          id: DocumentBlockId('b'),
          revision: 0,
          estimatedExtent: 100,
        ),
        const DocumentExtentSeed(
          id: DocumentBlockId('c'),
          revision: 0,
          estimatedExtent: 100,
        ),
      ]);
    final frozen = geometry.freeze(viewportExtent: 80);
    final before = frozen.thumb(physicalPixels: 110, trackExtent: 200);

    final correction = geometry.measure(
      id: const DocumentBlockId('a'),
      itemRevision: 0,
      layoutRevision: 0,
      extent: 140,
      anchor: const DocumentBlockId('c'),
    )!;
    frozen.absorb(correction);
    final after = frozen.thumb(physicalPixels: 150, trackExtent: 200);

    expect(correction.scrollOffsetDelta, 40);
    expect(after.offset, before.offset);
    expect(after.extent, before.extent);
  });

  test('reset, revision, and relayout keep identity-addressable geometry', () {
    final geometry = factory.create()
      ..reset([
        const DocumentExtentSeed(
          id: DocumentBlockId('a'),
          revision: 0,
          estimatedExtent: 20,
        ),
        const DocumentExtentSeed(
          id: DocumentBlockId('b'),
          revision: 0,
          estimatedExtent: 30,
        ),
      ], layoutRevision: 0);

    expect(geometry.blockAtOffset(25), const DocumentBlockId('b'));
    final revised = geometry.revise(
      seed: const DocumentExtentSeed(
        id: DocumentBlockId('a'),
        revision: 1,
        estimatedExtent: 40,
      ),
      anchor: const DocumentBlockId('b'),
    );
    final relaid = geometry.relayout(
      revision: 1,
      estimatedExtents: const [50, 60],
      anchor: const DocumentBlockId('b'),
    );

    expect(revised.scrollOffsetDelta, 20);
    expect(relaid.scrollOffsetDelta, 10);
    expect(geometry.leadingOffsetOf(const DocumentBlockId('b')), 50);
    expect(geometry.totalExtent, 110);

    final scaled = geometry.scaleRelayout(
      revision: 2,
      scale: 2,
      anchor: const DocumentBlockId('b'),
    );
    expect(scaled.scrollOffsetDelta, 50);
    expect(geometry.leadingOffsetOf(const DocumentBlockId('b')), 100);
    expect(geometry.totalExtent, 220);
  });

  test('tail replacement retains measured prefix geometry and identity', () {
    final geometry = factory.create()
      ..appendAll([
        const DocumentExtentSeed(
          id: DocumentBlockId('a'),
          revision: 0,
          estimatedExtent: 20,
        ),
        const DocumentExtentSeed(
          id: DocumentBlockId('provisional'),
          revision: 0,
          estimatedExtent: 30,
        ),
      ]);
    geometry.measure(
      id: const DocumentBlockId('a'),
      itemRevision: 0,
      layoutRevision: 0,
      extent: 27,
    );

    final correction = geometry.replaceTail(
      start: 1,
      seeds: const [
        DocumentExtentSeed(
          id: DocumentBlockId('final-1'),
          revision: 1,
          estimatedExtent: 40,
        ),
        DocumentExtentSeed(
          id: DocumentBlockId('final-2'),
          revision: 1,
          estimatedExtent: 50,
        ),
      ],
      anchor: const DocumentBlockId('a'),
    );

    expect(geometry.leadingOffsetOf(const DocumentBlockId('final-1')), 27);
    expect(geometry.indexOf(const DocumentBlockId('final-2')), 2);
    expect(geometry.totalExtent, 117);
    expect(correction.contentExtentDelta, 60);
    expect(correction.scrollOffsetDelta, 0);
    expect(
      () => geometry.indexOf(const DocumentBlockId('provisional')),
      throwsStateError,
    );
  });
}
