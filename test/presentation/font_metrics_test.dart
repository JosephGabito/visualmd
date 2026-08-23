import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/api/theme/font_licences.dart';
import 'package:visualmd/api/theme/font_metrics.dart';

/// The families the app actually ships, read from the manifest rather than
/// from a second list that could disagree with it.
Iterable<String> declaredFamilies() sync* {
  final lines = File('pubspec.yaml').readAsLinesSync();
  for (final line in lines) {
    final match = RegExp(r'^\s*-\s*family:\s*(.+?)\s*$').firstMatch(line);
    if (match != null) yield match[1]!;
  }
}

void main() {
  test('the manifest and the bundled list agree on what ships', () {
    expect(declaredFamilies().toSet(), bundledFontLicences.keys.toSet());
  });

  group('every bundled face has been measured', () {
    // A face added to the manifest without its measurements would be set at
    // its nominal size and its own natural leading — silently smaller or
    // larger than everything else on the page, with nothing to say so.
    for (final family in declaredFamilies()) {
      test(family, () {
        expect(
          FontMetrics.xHeights[family],
          isNotNull,
          reason:
              'without an x-height, $family is set at the wrong letter size',
        );
        expect(FontMetrics.capHeights[family], isNotNull);
        expect(FontMetrics.descenders[family], isNotNull);

        // Sanity, in case a value was transcribed from the wrong table.
        expect(FontMetrics.xHeights[family], inExclusiveRange(0.35, 0.65));
        expect(FontMetrics.capHeights[family], inExclusiveRange(0.55, 0.85));
        expect(FontMetrics.descenders[family], inExclusiveRange(0.15, 0.45));
        expect(
          FontMetrics.xHeights[family]!,
          lessThan(FontMetrics.capHeights[family]!),
          reason: 'x-height above cap height means the two were swapped',
        );
      });
    }
  });

  test('each licence file named actually ships', () {
    for (final path in bundledFontLicences.values) {
      expect(
        File(path).existsSync(),
        isTrue,
        reason: '$path is declared but missing',
      );
    }
  });

  test(
    'every measured face produces the same letter size and a usable leading',
    () {
      for (final family in FontMetrics.xHeights.keys) {
        final letters =
            FontMetrics.sizeFor(family, 18) * FontMetrics.xHeights[family]!;
        expect(
          letters,
          closeTo(18 * FontMetrics.referenceXHeight, 0.001),
          reason: family,
        );

        final leading = FontMetrics.leadingFor(family, 1.5);
        expect(
          leading,
          inExclusiveRange(1.3, 1.9),
          reason: '$family would set lines at an unreadable density',
        );
      }
    },
  );
}
