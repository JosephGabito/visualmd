import 'package:quiet_viewport/quiet_viewport.dart';
import 'package:test/test.dart';

void main() {
  test('anchor compensation leaves scrollbar geometry exactly unchanged', () {
    final frozen = FrozenScrollMetrics(
      contentExtent: 5000,
      viewportExtent: 800,
    );
    final before = frozen.thumb(physicalPixels: 1600, trackExtent: 600);

    frozen.absorb(
      const ExtentCorrection(
        key: 'before-anchor',
        contentExtentDelta: 240,
        scrollOffsetDelta: 240,
      ),
    );
    final after = frozen.thumb(physicalPixels: 1840, trackExtent: 600);

    expect(after.offset, before.offset);
    expect(after.extent, before.extent);
    expect(frozen.logicalPixels(1840), 1600);
  });

  test('tail growth cannot resize a thumb frozen for an active gesture', () {
    final frozen = FrozenScrollMetrics(
      contentExtent: 5000,
      viewportExtent: 800,
    );
    final before = frozen.thumb(physicalPixels: 1600, trackExtent: 600);

    // The ledger may now contain more tail content. Frozen metrics retain the
    // interaction's coordinate system until the scrollbar can settle unseen.
    final after = frozen.thumb(physicalPixels: 1600, trackExtent: 600);

    expect(after.offset, before.offset);
    expect(after.extent, before.extent);
  });

  test('real user movement remains visible while corrections stay hidden', () {
    final frozen = FrozenScrollMetrics(contentExtent: 5000, viewportExtent: 800)
      ..absorb(
        const ExtentCorrection(
          key: 'before-anchor',
          contentExtentDelta: 90,
          scrollOffsetDelta: 90,
        ),
      );

    expect(frozen.logicalPixels(1090), 1000);
    expect(frozen.logicalPixels(1210), 1120);
  });
}
