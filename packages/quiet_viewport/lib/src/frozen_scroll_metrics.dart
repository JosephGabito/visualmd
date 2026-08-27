import 'extent_ledger.dart';

/// A scrollbar thumb expressed in track coordinates.
final class ScrollThumbGeometry {
  final double offset;
  final double extent;

  const ScrollThumbGeometry({required this.offset, required this.extent});
}

/// A stable logical view of scroll metrics during one visible interaction.
///
/// Lazy layout may correct physical coordinates as item estimates become real.
/// Those corrections are not user movement and must not move the scrollbar.
/// The frozen model subtracts their accumulated bias from physical pixels and
/// keeps the content extent captured at interaction start.
final class FrozenScrollMetrics {
  final double contentExtent;
  final double viewportExtent;
  double _correctionBias = 0;

  FrozenScrollMetrics({
    required this.contentExtent,
    required this.viewportExtent,
  }) {
    _requireDimension(contentExtent, 'contentExtent');
    _requireDimension(viewportExtent, 'viewportExtent');
  }

  double get correctionBias => _correctionBias;
  double get maximumScrollExtent =>
      (contentExtent - viewportExtent).clamp(0, double.infinity);

  /// Absorbs the physical offset adjustment used to hold an anchor still.
  void absorb<K extends Object>(ExtentCorrection<K> correction) {
    _correctionBias += correction.scrollOffsetDelta;
  }

  /// User-space pixels with automatic layout corrections removed.
  double logicalPixels(double physicalPixels) =>
      (physicalPixels - _correctionBias).clamp(0, maximumScrollExtent);

  ScrollThumbGeometry thumb({
    required double physicalPixels,
    required double trackExtent,
    double minimumThumbExtent = 18,
  }) {
    _requireDimension(trackExtent, 'trackExtent');
    _requireDimension(minimumThumbExtent, 'minimumThumbExtent');
    if (trackExtent == 0) {
      return const ScrollThumbGeometry(offset: 0, extent: 0);
    }
    if (contentExtent <= viewportExtent || contentExtent == 0) {
      return ScrollThumbGeometry(offset: 0, extent: trackExtent);
    }

    final minimum = minimumThumbExtent.clamp(0.0, trackExtent).toDouble();
    final extent = (trackExtent * viewportExtent / contentExtent)
        .clamp(minimum, trackExtent)
        .toDouble();
    final travel = trackExtent - extent;
    final progress = logicalPixels(physicalPixels) / maximumScrollExtent;
    return ScrollThumbGeometry(offset: travel * progress, extent: extent);
  }

  static void _requireDimension(double value, String name) {
    if (!value.isFinite || value < 0) {
      throw RangeError.value(value, name, 'Must be finite and nonnegative');
    }
  }
}
