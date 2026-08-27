import 'package:quiet_viewport/quiet_viewport.dart';
import 'package:test/test.dart';

void main() {
  test('bulk construction preserves every prefix and boundary', () {
    final ledger = StableExtentLedger<int>()
      ..appendAll([
        for (var index = 0; index < 1000; index++)
          ExtentSeed(
            key: index,
            revision: 0,
            estimatedExtent: (index % 7 + 1).toDouble(),
          ),
      ]);

    var prefix = 0.0;
    for (var index = 0; index < 1000; index++) {
      expect(ledger.leadingOffsetOf(index), prefix);
      expect(ledger.keyAtOffset(prefix), index);
      prefix += (index % 7 + 1).toDouble();
    }
    expect(ledger.totalExtent, prefix);
  });

  test('an empty ledger can begin a new layout epoch', () {
    final ledger = StableExtentLedger<String>();

    final correction = ledger.relayout(revision: 1, estimatedExtents: const []);

    expect(correction.key, isNull);
    expect(correction.contentExtentDelta, 0);
    expect(correction.scrollOffsetDelta, 0);
    expect(ledger.layoutRevision, 1);
  });

  test('dynamic appends preserve exact logarithmic prefix sums', () {
    final ledger = StableExtentLedger<String>();
    for (var index = 0; index < 4096; index++) {
      ledger.append(
        ExtentSeed(
          key: 'block-$index',
          revision: 0,
          estimatedExtent: index + 1,
        ),
      );
    }

    expect(ledger.leadingOffsetOf('block-0'), 0);
    expect(ledger.leadingOffsetOf('block-2048'), 2048 * 2049 / 2);
    expect(ledger.totalExtent, 4096 * 4097 / 2);
  });

  test('a correction before the anchor produces exact compensation', () {
    final ledger = StableExtentLedger<String>()
      ..appendAll([
        const ExtentSeed(key: 'a', revision: 0, estimatedExtent: 100),
        const ExtentSeed(key: 'b', revision: 0, estimatedExtent: 100),
        const ExtentSeed(key: 'c', revision: 0, estimatedExtent: 100),
      ]);

    final correction = ledger.measure(
      key: 'a',
      itemRevision: 0,
      layoutRevision: 0,
      extent: 145,
      anchor: 'c',
    )!;

    expect(correction.contentExtentDelta, 45);
    expect(correction.scrollOffsetDelta, 45);
    expect(ledger.leadingOffsetOf('c'), 245);
  });

  test(
    'offset lookup observes half-open item boundaries in logarithmic time',
    () {
      final ledger = StableExtentLedger<String>()
        ..appendAll([
          const ExtentSeed(key: 'a', revision: 0, estimatedExtent: 40),
          const ExtentSeed(key: 'b', revision: 0, estimatedExtent: 60),
          const ExtentSeed(key: 'c', revision: 0, estimatedExtent: 80),
        ]);

      expect(ledger.keyAtOffset(-20), 'a');
      expect(ledger.keyAtOffset(39.999), 'a');
      expect(ledger.keyAtOffset(40), 'b');
      expect(ledger.keyAtOffset(99.999), 'b');
      expect(ledger.keyAtOffset(100), 'c');
      expect(ledger.keyAtOffset(10000), 'c');
    },
  );

  test('a rejected append batch leaves the ledger unchanged', () {
    final ledger = StableExtentLedger<String>()
      ..append(
        const ExtentSeed(key: 'existing', revision: 0, estimatedExtent: 20),
      );

    expect(
      () => ledger.appendAll([
        const ExtentSeed(key: 'new', revision: 0, estimatedExtent: 30),
        const ExtentSeed(key: 'existing', revision: 0, estimatedExtent: 40),
      ]),
      throwsStateError,
    );
    expect(ledger.keys, ['existing']);
    expect(ledger.totalExtent, 20);
  });

  test('a negative item revision is rejected in every runtime mode', () {
    final ledger = StableExtentLedger<String>();

    expect(
      () => ledger.append(
        const ExtentSeed(key: 'invalid', revision: -1, estimatedExtent: 20),
      ),
      throwsRangeError,
    );
  });

  test('a correction at or after the anchor never moves the anchor', () {
    final ledger = StableExtentLedger<String>()
      ..appendAll([
        const ExtentSeed(key: 'a', revision: 0, estimatedExtent: 100),
        const ExtentSeed(key: 'b', revision: 0, estimatedExtent: 100),
        const ExtentSeed(key: 'c', revision: 0, estimatedExtent: 100),
      ]);

    expect(
      ledger
          .measure(
            key: 'b',
            itemRevision: 0,
            layoutRevision: 0,
            extent: 130,
            anchor: 'b',
          )!
          .scrollOffsetDelta,
      0,
    );
    expect(
      ledger
          .measure(
            key: 'c',
            itemRevision: 0,
            layoutRevision: 0,
            extent: 160,
            anchor: 'b',
          )!
          .scrollOffsetDelta,
      0,
    );
  });

  test('stale item and layout measurements cannot alter geometry', () {
    final ledger = StableExtentLedger<String>()
      ..append(const ExtentSeed(key: 'tail', revision: 3, estimatedExtent: 80));

    expect(
      ledger.measure(
        key: 'tail',
        itemRevision: 2,
        layoutRevision: 0,
        extent: 800,
      ),
      isNull,
    );
    expect(
      ledger.measure(
        key: 'tail',
        itemRevision: 3,
        layoutRevision: 1,
        extent: 800,
      ),
      isNull,
    );
    expect(ledger.totalExtent, 80);
  });

  test(
    'relayout compensates the anchor once for the new coordinate system',
    () {
      final ledger = StableExtentLedger<String>()
        ..appendAll([
          const ExtentSeed(key: 'a', revision: 0, estimatedExtent: 40),
          const ExtentSeed(key: 'b', revision: 0, estimatedExtent: 50),
          const ExtentSeed(key: 'c', revision: 0, estimatedExtent: 60),
        ]);

      final correction = ledger.relayout(
        revision: 1,
        estimatedExtents: const [60, 70, 80],
        anchor: 'c',
      );

      expect(correction.contentExtentDelta, 60);
      expect(correction.scrollOffsetDelta, 40);
      expect(ledger.leadingOffsetOf('c'), 130);
    },
  );

  test('a tail replacement retains prefix geometry and direct lookup', () {
    final ledger = StableExtentLedger<String>()
      ..appendAll(const [
        ExtentSeed(key: 'a', revision: 0, estimatedExtent: 10),
        ExtentSeed(key: 'b', revision: 0, estimatedExtent: 20),
        ExtentSeed(key: 'tail', revision: 0, estimatedExtent: 30),
      ]);
    ledger.measure(key: 'b', itemRevision: 0, layoutRevision: 0, extent: 24);

    final correction = ledger.replaceTail(
      start: 2,
      seeds: const [
        ExtentSeed(key: 'tail', revision: 1, estimatedExtent: 12),
        ExtentSeed(key: 'next', revision: 1, estimatedExtent: 16),
      ],
      anchor: 'b',
    );

    expect(ledger.extentOf('b'), 24);
    expect(ledger.indexOf('tail'), 2);
    expect(ledger.indexOf('next'), 3);
    expect(ledger.leadingOffsetOf('next'), 46);
    expect(correction.scrollOffsetDelta, 0);
    expect(correction.contentExtentDelta, -2);
  });
}
