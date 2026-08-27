import 'package:quiet_viewport/quiet_viewport.dart';

import '../../application/ports/document_viewport_geometry.dart';
import '../../domain/reading/content/document_content.dart';

/// Infrastructure adapter for Quiet Viewport's standalone geometry engine.
final class QuietDocumentViewportGeometryFactory
    implements DocumentViewportGeometryFactory {
  const QuietDocumentViewportGeometryFactory();

  @override
  DocumentViewportGeometry create({int layoutRevision = 0}) =>
      _QuietDocumentViewportGeometry(layoutRevision: layoutRevision);

  @override
  FrozenDocumentScrollMetrics freezeMetrics({
    required double contentExtent,
    required double viewportExtent,
  }) => _QuietFrozenDocumentScrollMetrics(
    FrozenScrollMetrics(
      contentExtent: contentExtent,
      viewportExtent: viewportExtent,
    ),
  );
}

final class _QuietDocumentViewportGeometry implements DocumentViewportGeometry {
  StableExtentLedger<DocumentBlockId> _ledger;
  final Map<DocumentBlockId, int> _revisions = {};

  _QuietDocumentViewportGeometry({required int layoutRevision})
    : _ledger = StableExtentLedger(layoutRevision: layoutRevision);

  @override
  int get length => _ledger.length;

  @override
  int get layoutRevision => _ledger.layoutRevision;

  @override
  double get totalExtent => _ledger.totalExtent;

  @override
  void appendAll(Iterable<DocumentExtentSeed> seeds) {
    final incoming = seeds.toList(growable: false);
    _ledger.appendAll(
      incoming.map(
        (seed) => ExtentSeed(
          key: seed.id,
          revision: seed.revision,
          estimatedExtent: seed.estimatedExtent,
        ),
      ),
    );
    for (final seed in incoming) {
      _revisions[seed.id] = seed.revision;
    }
  }

  @override
  DocumentExtentCorrection replaceTail({
    required int start,
    required Iterable<DocumentExtentSeed> seeds,
    DocumentBlockId? anchor,
  }) {
    final incoming = seeds.toList(growable: false);
    final removed = _ledger.keys.skip(start).toList(growable: false);
    final correction = _ledger.replaceTail(
      start: start,
      seeds: [
        for (final seed in incoming)
          ExtentSeed(
            key: seed.id,
            revision: seed.revision,
            estimatedExtent: seed.estimatedExtent,
          ),
      ],
      anchor: anchor,
    );
    for (final id in removed) {
      _revisions.remove(id);
    }
    for (final seed in incoming) {
      _revisions[seed.id] = seed.revision;
    }
    return _correction(correction);
  }

  @override
  DocumentExtentCorrection reset(
    Iterable<DocumentExtentSeed> seeds, {
    required int layoutRevision,
    DocumentBlockId? anchor,
  }) {
    final incoming = seeds.toList(growable: false);
    final totalBefore = _ledger.totalExtent;
    final retainedAnchor = anchor != null && _revisions.containsKey(anchor);
    final anchorBefore = retainedAnchor ? _ledger.leadingOffsetOf(anchor) : 0.0;
    final retained = <DocumentBlockId, double>{};
    for (final seed in incoming) {
      if (_revisions[seed.id] == seed.revision) {
        retained[seed.id] = _ledger.extentOf(seed.id);
      }
    }
    _ledger = StableExtentLedger(layoutRevision: layoutRevision);
    _revisions.clear();
    appendAll([
      for (final seed in incoming)
        DocumentExtentSeed(
          id: seed.id,
          revision: seed.revision,
          estimatedExtent: retained[seed.id] ?? seed.estimatedExtent,
        ),
    ]);
    final anchorAfter = anchor != null && _revisions.containsKey(anchor)
        ? _ledger.leadingOffsetOf(anchor)
        : anchorBefore;
    return DocumentExtentCorrection(
      contentExtentDelta: _ledger.totalExtent - totalBefore,
      scrollOffsetDelta: retainedAnchor ? anchorAfter - anchorBefore : 0,
    );
  }

  @override
  double leadingOffsetOf(DocumentBlockId id) => _ledger.leadingOffsetOf(id);

  @override
  int indexOf(DocumentBlockId id) => _ledger.indexOf(id);

  @override
  DocumentBlockId? blockAtOffset(double offset) => _ledger.keyAtOffset(offset);

  @override
  DocumentExtentCorrection revise({
    required DocumentExtentSeed seed,
    DocumentBlockId? anchor,
  }) {
    final correction = _ledger.revise(
      key: seed.id,
      revision: seed.revision,
      estimatedExtent: seed.estimatedExtent,
      anchor: anchor,
    );
    _revisions[seed.id] = seed.revision;
    return _correction(correction);
  }

  @override
  DocumentExtentCorrection relayout({
    required int revision,
    required Iterable<double> estimatedExtents,
    DocumentBlockId? anchor,
  }) => _correction(
    _ledger.relayout(
      revision: revision,
      estimatedExtents: estimatedExtents,
      anchor: anchor,
    ),
  );

  @override
  DocumentExtentCorrection scaleRelayout({
    required int revision,
    required double scale,
    DocumentBlockId? anchor,
  }) => _correction(
    _ledger.scaleRelayout(revision: revision, scale: scale, anchor: anchor),
  );

  @override
  DocumentExtentCorrection? measure({
    required DocumentBlockId id,
    required int itemRevision,
    required int layoutRevision,
    required double extent,
    DocumentBlockId? anchor,
  }) {
    final correction = _ledger.measure(
      key: id,
      itemRevision: itemRevision,
      layoutRevision: layoutRevision,
      extent: extent,
      anchor: anchor,
    );
    return correction == null ? null : _correction(correction);
  }

  @override
  FrozenDocumentScrollMetrics freeze({required double viewportExtent}) =>
      _QuietFrozenDocumentScrollMetrics(
        FrozenScrollMetrics(
          contentExtent: totalExtent,
          viewportExtent: viewportExtent,
        ),
      );

  static DocumentExtentCorrection _correction(
    ExtentCorrection<DocumentBlockId> correction,
  ) => DocumentExtentCorrection(
    contentExtentDelta: correction.contentExtentDelta,
    scrollOffsetDelta: correction.scrollOffsetDelta,
  );
}

final class _QuietFrozenDocumentScrollMetrics
    implements FrozenDocumentScrollMetrics {
  final FrozenScrollMetrics _metrics;

  const _QuietFrozenDocumentScrollMetrics(this._metrics);

  @override
  double get correctionBias => _metrics.correctionBias;

  @override
  double get maximumScrollExtent => _metrics.maximumScrollExtent;

  @override
  void absorb(DocumentExtentCorrection correction) {
    _metrics.absorb(
      ExtentCorrection(
        key: const DocumentBlockId('geometry-correction'),
        contentExtentDelta: correction.contentExtentDelta,
        scrollOffsetDelta: correction.scrollOffsetDelta,
      ),
    );
  }

  @override
  double logicalPixels(double physicalPixels) =>
      _metrics.logicalPixels(physicalPixels);

  @override
  DocumentScrollThumb thumb({
    required double physicalPixels,
    required double trackExtent,
    double minimumThumbExtent = 18,
  }) {
    final thumb = _metrics.thumb(
      physicalPixels: physicalPixels,
      trackExtent: trackExtent,
      minimumThumbExtent: minimumThumbExtent,
    );
    return DocumentScrollThumb(offset: thumb.offset, extent: thumb.extent);
  }
}
