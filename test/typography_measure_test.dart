// A measuring stick, not a guard: run it to see what the bundled faces
// actually do, then encode the conclusions in the reading style.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> loadFont(String family, List<String> assets) async {
  final loader = FontLoader(family);
  for (final asset in assets) {
    loader.addFont(rootBundle.load(asset));
  }
  await loader.load();
}

double widthOf(String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
  )..layout();
  return painter.width;
}

/// A paragraph of ordinary English: the mix of letters a reader actually meets.
const sample =
    'The system already completes complex work. The inventory explains why that '
    'work remains correct when a component changes or a worker stops. It gives '
    'each system responsibility one clear owner, and shows how those owners '
    'cooperate during a request.';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await loadFont('Literata', [
      'assets/fonts/Literata.ttf',
      'assets/fonts/Literata-Italic.ttf',
    ]);
    await loadFont('Inter', [
      'assets/fonts/Inter.ttf',
      'assets/fonts/Inter-Italic.ttf',
    ]);
    await loadFont('Geist Mono', ['assets/fonts/GeistMono.ttf']);
  });

  test('does fontWeight reach a variable font?', () {
    const base = TextStyle(fontFamily: 'Literata', fontSize: 18);
    final regular = widthOf(sample, base);
    final bold = widthOf(sample, base.copyWith(fontWeight: FontWeight.w700));
    final byAxis = widthOf(
      sample,
      base.copyWith(fontVariations: const [FontVariation('wght', 700)]),
    );
    debugPrint(
      'WEIGHT  regular=${regular.toStringAsFixed(1)} '
      'fontWeight700=${bold.toStringAsFixed(1)} '
      'fontVariation700=${byAxis.toStringAsFixed(1)}',
    );
  });

  test('does an explicit optical size clobber the weight?', () {
    const base = TextStyle(fontFamily: 'Literata', fontSize: 18);
    final plain700 = widthOf(
      sample,
      base.copyWith(fontWeight: FontWeight.w700),
    );
    final opszOnly = widthOf(
      sample,
      base.copyWith(
        fontWeight: FontWeight.w700,
        fontVariations: const [FontVariation('opsz', 18)],
      ),
    );
    final both = widthOf(
      sample,
      base.copyWith(
        fontVariations: const [
          FontVariation('opsz', 18),
          FontVariation('wght', 700),
        ],
      ),
    );
    final display = widthOf(
      sample,
      base.copyWith(
        fontVariations: const [
          FontVariation('opsz', 60),
          FontVariation('wght', 400),
        ],
      ),
    );
    final text = widthOf(
      sample,
      base.copyWith(
        fontVariations: const [
          FontVariation('opsz', 8),
          FontVariation('wght', 400),
        ],
      ),
    );
    debugPrint(
      'OPSZ    fontWeight700=${plain700.toStringAsFixed(1)} '
      'weight+opsz=${opszOnly.toStringAsFixed(1)} '
      'bothAxes=${both.toStringAsFixed(1)}',
    );
    debugPrint(
      'OPSZ    display(60)=${display.toStringAsFixed(1)} '
      'text(8)=${text.toStringAsFixed(1)} '
      'default=${widthOf(sample, base).toStringAsFixed(1)}',
    );
  });

  test('how many characters fit on a line?', () {
    for (final size in [17.0, 18.0, 19.0, 20.0]) {
      final style = TextStyle(fontFamily: 'Literata', fontSize: size);
      final advance = widthOf(sample, style) / sample.length;
      final line = <String>[];
      for (final width in [600, 640, 680, 720, 760]) {
        line.add('$width:${(width / advance).round()}');
      }
      debugPrint(
        'MEASURE ${size.toStringAsFixed(0)}px advance='
        '${advance.toStringAsFixed(2)}px  chars-per-width  ${line.join('  ')}',
      );
    }
  });

  test('what width holds a 66-character line?', () {
    for (final size in [17.0, 18.0, 19.0, 20.0]) {
      final style = TextStyle(fontFamily: 'Literata', fontSize: size);
      final advance = widthOf(sample, style) / sample.length;
      debugPrint(
        'TARGET  ${size.toStringAsFixed(0)}px  '
        '60ch=${(60 * advance).round()}px  '
        '66ch=${(66 * advance).round()}px  '
        '75ch=${(75 * advance).round()}px',
      );
    }
  });

  test('how do the three faces compare at the same size?', () {
    for (final family in ['Literata', 'Inter', 'Geist Mono']) {
      final style = TextStyle(fontFamily: family, fontSize: 18);
      final painter = TextPainter(
        text: TextSpan(text: 'Handgloves', style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      final metrics = painter.computeLineMetrics().first;
      debugPrint(
        'FACE    $family  advance=${(widthOf(sample, style) / sample.length).toStringAsFixed(2)} '
        'ascent=${metrics.ascent.toStringAsFixed(1)} descent=${metrics.descent.toStringAsFixed(1)} '
        'height=${metrics.height.toStringAsFixed(1)}',
      );
    }
  });
}
