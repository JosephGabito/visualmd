import '../../domain/reading/content/document_content.dart';

/// Geometry known before a lazy document block is mounted.
final class DocumentExtentSeed {
  final DocumentBlockId id;
  final int revision;
  final double estimatedExtent;

  const DocumentExtentSeed({
    required this.id,
    required this.revision,
    required this.estimatedExtent,
  });
}

/// A coordinate-system correction caused by better block geometry.
final class DocumentExtentCorrection {
  final double contentExtentDelta;
  final double scrollOffsetDelta;

  const DocumentExtentCorrection({
    required this.contentExtentDelta,
    required this.scrollOffsetDelta,
  });
}

/// Stable thumb geometry in scrollbar-track coordinates.
final class DocumentScrollThumb {
  final double offset;
  final double extent;

  const DocumentScrollThumb({required this.offset, required this.extent});
}

/// Logical scroll metrics frozen for one visible interaction.
abstract interface class FrozenDocumentScrollMetrics {
  double get correctionBias;
  double get maximumScrollExtent;

  void absorb(DocumentExtentCorrection correction);

  double logicalPixels(double physicalPixels);

  DocumentScrollThumb thumb({
    required double physicalPixels,
    required double trackExtent,
    double minimumThumbExtent,
  });
}

/// A document-scoped geometry ledger.
abstract interface class DocumentViewportGeometry {
  int get length;
  int get layoutRevision;
  double get totalExtent;

  void appendAll(Iterable<DocumentExtentSeed> seeds);

  /// Replaces the complete sequence after a non-append structural mutation.
  DocumentExtentCorrection reset(
    Iterable<DocumentExtentSeed> seeds, {
    required int layoutRevision,
    DocumentBlockId? anchor,
  });

  double leadingOffsetOf(DocumentBlockId id);

  DocumentBlockId? blockAtOffset(double offset);

  DocumentExtentCorrection revise({
    required DocumentExtentSeed seed,
    DocumentBlockId? anchor,
  });

  DocumentExtentCorrection relayout({
    required int revision,
    required Iterable<double> estimatedExtents,
    DocumentBlockId? anchor,
  });

  DocumentExtentCorrection? measure({
    required DocumentBlockId id,
    required int itemRevision,
    required int layoutRevision,
    required double extent,
    DocumentBlockId? anchor,
  });

  FrozenDocumentScrollMetrics freeze({required double viewportExtent});
}

/// Creates fresh geometry for one document/layout lifetime.
abstract interface class DocumentViewportGeometryFactory {
  const DocumentViewportGeometryFactory();

  DocumentViewportGeometry create({int layoutRevision = 0});

  /// Captures the coordinate system used by one visible scroll interaction.
  FrozenDocumentScrollMetrics freezeMetrics({
    required double contentExtent,
    required double viewportExtent,
  });
}
