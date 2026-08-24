import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/api/render/reading_theme.dart';
import 'package:visualmd/api/theme/font_metrics.dart';
import 'package:visualmd/api/theme/library_theme.dart';
import 'package:visualmd/api/theme/reading_measure.dart';
import 'package:visualmd/presentation/theme/built_in_themes.dart';
import 'package:visualmd/presentation/theme/reading_scale.dart';
import 'package:visualmd/presentation/theme/theme_typefaces.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Whatever the library's reading face is, that is the one measured.
    final files = {
      'Alegreya': 'Alegreya.ttf',
      'Literata': 'Literata.ttf',
      'Geist Mono': 'GeistMono.ttf',
    };
    for (final entry in files.entries) {
      await (FontLoader(
        entry.key,
      )..addFont(rootBundle.load('assets/fonts/${entry.value}'))).load();
    }
  });

  const scale = ReadingScale.comfortable;

  group('the scale holds its proportions', () {
    test('no heading is smaller than the text it heads', () {
      for (var level = 1; level <= 6; level++) {
        expect(
          scale.heading(level),
          greaterThanOrEqualTo(scale.base),
          reason: 'h$level',
        );
      }
    });

    test('every step up is visible, and none is a leap', () {
      for (var level = 5; level >= 1; level--) {
        final ratio = scale.heading(level) / scale.heading(level + 1);
        expect(
          ratio,
          greaterThan(1.09),
          reason: 'h$level barely differs from h${level + 1}',
        );
        expect(
          ratio,
          lessThan(1.35),
          reason: 'h$level leaps away from h${level + 1}',
        );
      }
    });

    test('reference code is visibly smaller and tighter than prose', () {
      expect(scale.base, 18);
      expect(scale.code, 15);
      expect(scale.codeLineHeight, 22);
      expect(scale.tableText, lessThan(scale.base));
    });

    test(
      'the code step follows the reader without crossing its size floor',
      () {
        final large = scale.copyWith(base: 22);
        expect(
          large.heading(2) / large.base,
          closeTo(scale.heading(2) / scale.base, 0.001),
        );
        expect(
          large.indent / large.base,
          closeTo(scale.indent / scale.base, 0.001),
        );
        expect(large.code, 19);
        expect(large.codeLineHeight, 26);
        expect(scale.copyWith(base: 15).code, ReadingScale.minimumCodeSize);
      },
    );
  });

  group('the measure, in the face actually used', () {
    TextStyle body(double size) => TextStyle(
      fontFamily: ThemeTypefaces.library.serif,
      fontSize: size,
      height: scale.leading,
    );

    test('a line holds 60 to 75 characters — the band the eye tracks', () {
      final width = ReadingMeasure.columnWidth(body(scale.base), scale.measure);
      final characters = width / ReadingMeasure.advance(body(scale.base));
      expect(characters, greaterThanOrEqualTo(60));
      expect(characters, lessThanOrEqualTo(75));
    });

    test('the column follows the size, so the measure never drifts', () {
      for (final size in [16.0, 18.0, 22.0, 26.0]) {
        final style = body(size);
        final width = ReadingMeasure.columnWidth(style, scale.measure);
        expect(
          width / ReadingMeasure.advance(style),
          closeTo(scale.measure, 0.001),
          reason: '${size}px',
        );
        expect(
          width,
          greaterThan(size * 20),
          reason: 'a column this narrow is a newspaper column',
        );
      }
    });

    test('a wider face gets a wider column, not a longer line', () {
      final serif = ReadingMeasure.columnWidth(body(scale.base), scale.measure);
      final mono = ReadingMeasure.columnWidth(
        TextStyle(fontFamily: 'Geist Mono', fontSize: scale.base),
        scale.measure,
      );
      expect(mono, isNot(closeTo(serif, 1)));
    });

    test('the cache distinguishes shaping details that change the line', () {
      final plain = body(scale.base);
      final tracked = plain.copyWith(letterSpacing: 1.5);
      expect(
        ReadingMeasure.widthOf('a measured sentence', tracked),
        greaterThan(ReadingMeasure.widthOf('a measured sentence', plain)),
      );
    });
  });

  group('accessibility scaling is part of the page geometry', () {
    Future<ReadingTheme> themeAt(WidgetTester tester, TextScaler scaler) async {
      ReadingTheme? theme;
      await tester.pumpWidget(
        MaterialApp(
          theme: libraryTheme(BuiltInThemes.paper),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: scaler),
            child: child!,
          ),
          home: Builder(
            builder: (context) {
              theme = ReadingTheme.of(context, scale);
              return const SizedBox();
            },
          ),
        ),
      );
      return theme!;
    }

    testWidgets('the measure and baseline grow with the rendered letters', (
      tester,
    ) async {
      final normal = await themeAt(tester, TextScaler.noScaling);
      final enlarged = await themeAt(tester, const TextScaler.linear(1.5));
      expect(enlarged.renderedBase, closeTo(normal.renderedBase * 1.5, 0.001));
      expect(enlarged.baseline, closeTo(normal.baseline * 1.5, 0.001));
      expect(
        enlarged.proseWidth(5000),
        closeTo(normal.proseWidth(5000) * 1.5, 0.5),
      );
    });

    testWidgets('display leading stays tight and proportional after scaling', (
      tester,
    ) async {
      final normal = await themeAt(tester, TextScaler.noScaling);
      final enlarged = await themeAt(tester, const TextScaler.linear(1.8));

      const maximumLeading = [1.15, 1.2, 1.25, 1.3, 1.4];
      for (var level = 1; level <= 6; level++) {
        final normalHeading = normal.heading(level);
        final enlargedHeading = enlarged.heading(level);
        expect(
          enlargedHeading.height,
          normalHeading.height,
          reason: 'scaling changes the letters, not their proportion',
        );
        if (level <= 5) {
          expect(
            enlargedHeading.height,
            lessThanOrEqualTo(maximumLeading[level - 1]),
            reason: 'h$level is display type, not a paragraph',
          );
        } else {
          expect(enlargedHeading.height, closeTo(enlarged.leading, 0.001));
        }
      }

      for (var level = 1; level < 6; level++) {
        expect(
          enlarged.heading(level).height!,
          lessThan(enlarged.heading(level + 1).height!),
          reason:
              'leading should open gradually as headings approach body size',
        );
      }

      final codeLine =
          enlarged.textScaler.scale(enlarged.code.fontSize!) *
          enlarged.code.height!;
      expect(
        codeLine,
        closeTo(
          enlarged.textScaler.scale(enlarged.scale.codeLineHeight),
          0.001,
        ),
      );
    });
  });

  group('a size is a size of letters', () {
    test(
      'a face with smaller letters is given the size that makes up for it',
      () {
        // Literata's x-height is 0.507 em against the 0.55 a size is quoted
        // against, so it is set larger to read the same.
        expect(FontMetrics.sizeFor('Literata', 18), greaterThan(18));
        expect(
          FontMetrics.sizeFor('Literata', 18) *
              FontMetrics.xHeights['Literata']!,
          closeTo(18 * FontMetrics.referenceXHeight, 0.001),
        );
      },
    );

    test('every bundled face ends up with the same letter size', () {
      final heights = [
        for (final family in FontMetrics.xHeights.keys)
          FontMetrics.sizeFor(family, 18) * FontMetrics.xHeights[family]!,
      ];
      for (final height in heights) {
        expect(
          height,
          closeTo(heights.first, 0.001),
          reason: 'faces must match optically',
        );
      }
    });

    test('a face we do not ship is left alone rather than guessed at', () {
      expect(FontMetrics.sizeFor('Some Themed Face', 18), 18);
    });
  });
}
