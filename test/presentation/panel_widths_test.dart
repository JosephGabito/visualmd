import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/api/layout/panel_widths.dart';

void main() {
  test('stored widths restore independently and reject unfamiliar values', () {
    expect(PanelWidths.fromStored('360', '310').shelf, 360);
    expect(
      PanelWidths.fromStored('broken', '310'),
      isA<PanelWidths>()
          .having((w) => w.shelf, 'shelf', PanelWidths.defaultShelf)
          .having((w) => w.outline, 'outline', 310),
    );
    expect(
      PanelWidths.fromStored('9999', '-20'),
      isA<PanelWidths>()
          .having((w) => w.shelf, 'shelf', PanelWidths.defaultShelf)
          .having((w) => w.outline, 'outline', PanelWidths.defaultOutline),
    );
  });

  test('a panel cannot be dragged past a useful or responsible width', () {
    const widths = PanelWidths();
    expect(widths.withShelf(0).shelf, PanelWidths.minimumShelf);
    expect(widths.withShelf(9999).shelf, PanelWidths.maximumShelf);
    expect(widths.withOutline(0).outline, PanelWidths.minimumOutline);
    expect(widths.withOutline(9999).outline, PanelWidths.maximumOutline);
  });

  test('side panels yield together before narrowing the measured page', () {
    const widths = PanelWidths(shelf: 500, outline: 400);
    final fitted = widths.fitWide(
      available: 1280,
      protectedCenter: 700,
      shelfVisible: true,
      outlineVisible: true,
    );

    expect(fitted.shelf + fitted.outline, closeTo(580, 0.001));
    expect(fitted.shelf, greaterThan(PanelWidths.minimumShelf));
    expect(fitted.outline, greaterThan(PanelWidths.minimumOutline));
    expect(widths.shelf, 500, reason: 'the preference itself is not clamped');
    expect(widths.outline, 400, reason: 'the preference itself is not clamped');
  });

  test('compact overlays leave an edge of the page visible', () {
    const widths = PanelWidths(shelf: 500, outline: 400);
    expect(widths.shelfForCompact(430), 374);
    expect(widths.outlineForCompact(430), 374);
  });
}
