import 'dart:math' as math;

/// The reader's preferred side-panel widths, independent of the current window.
///
/// A preference is kept even when a smaller window cannot honour it. The shell
/// derives fitted widths for that window, so returning to a larger room restores
/// what the reader chose instead of persisting an accidental clamp.
final class PanelWidths {
  static const double defaultShelf = 280;
  static const double defaultOutline = 240;

  static const double minimumShelf = 220;
  static const double maximumShelf = 520;
  static const double minimumOutline = 200;
  static const double maximumOutline = 440;

  /// Compact overlays leave this much of the opposite edge visible.
  static const double compactEdgeClearance = 56;

  final double shelf;
  final double outline;

  const PanelWidths({this.shelf = defaultShelf, this.outline = defaultOutline});

  /// Restores only values the current reader understands.
  ///
  /// A malformed or obsolete preference falls back independently, so one bad
  /// side never discards the reader's valid choice for the other.
  factory PanelWidths.fromStored(String? shelf, String? outline) => PanelWidths(
    shelf: _restored(
      shelf,
      minimum: minimumShelf,
      maximum: maximumShelf,
      fallback: defaultShelf,
    ),
    outline: _restored(
      outline,
      minimum: minimumOutline,
      maximum: maximumOutline,
      fallback: defaultOutline,
    ),
  );

  PanelWidths withShelf(double width) => PanelWidths(
    shelf: width.clamp(minimumShelf, maximumShelf),
    outline: outline,
  );

  PanelWidths withOutline(double width) => PanelWidths(
    shelf: shelf,
    outline: width.clamp(minimumOutline, maximumOutline),
  );

  PanelWidths resetShelf() => PanelWidths(outline: outline);

  PanelWidths resetOutline() => PanelWidths(shelf: shelf);

  /// Fits visible panels into the space left after protecting the page.
  ///
  /// Width above each panel's minimum is discretionary. If the window cannot
  /// honour both preferences, that discretionary room is reduced in the same
  /// proportion on both sides. Neither panel silently wins at the expense of
  /// the other, and the stored preferences remain untouched.
  ({double shelf, double outline}) fitWide({
    required double available,
    required double protectedCenter,
    required bool shelfVisible,
    required bool outlineVisible,
  }) {
    if (!shelfVisible && !outlineVisible) return (shelf: 0, outline: 0);

    final budget = math.max(0.0, available - protectedCenter);
    final wantedShelf = shelfVisible ? shelf : 0.0;
    final wantedOutline = outlineVisible ? outline : 0.0;
    if (wantedShelf + wantedOutline <= budget) {
      return (shelf: wantedShelf, outline: wantedOutline);
    }

    final floorShelf = shelfVisible ? minimumShelf : 0.0;
    final floorOutline = outlineVisible ? minimumOutline : 0.0;
    final floorTotal = floorShelf + floorOutline;
    if (budget <= floorTotal) {
      final fraction = floorTotal == 0 ? 0.0 : budget / floorTotal;
      return (shelf: floorShelf * fraction, outline: floorOutline * fraction);
    }

    final extraShelf = wantedShelf - floorShelf;
    final extraOutline = wantedOutline - floorOutline;
    final wantedExtra = extraShelf + extraOutline;
    final fittedExtra = budget - floorTotal;
    final fraction = wantedExtra == 0 ? 0.0 : fittedExtra / wantedExtra;
    return (
      shelf: floorShelf + extraShelf * fraction,
      outline: floorOutline + extraOutline * fraction,
    );
  }

  double shelfForCompact(double available) =>
      math.min(shelf, math.max(0, available - compactEdgeClearance));

  double outlineForCompact(double available) =>
      math.min(outline, math.max(0, available - compactEdgeClearance));

  static double _restored(
    String? stored, {
    required double minimum,
    required double maximum,
    required double fallback,
  }) {
    final width = double.tryParse(stored ?? '');
    if (width == null ||
        !width.isFinite ||
        width < minimum ||
        width > maximum) {
      return fallback;
    }
    return width;
  }
}
