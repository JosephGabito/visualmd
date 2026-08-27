import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:visualmd/api/highlighting/shiki_code_highlighter.dart';
import 'package:visualmd/presentation/code/code_highlighter.dart';

/// Records the classification cost hidden behind an otherwise lazy code view.
///
/// Layout can be viewport-bounded while an enhancement still tokenizes the
/// complete fence. This profile target measures the production Shiki adapter
/// directly so renderer timings cannot conceal that asynchronous work.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('syntax classification exposes its source-length slope', (
    tester,
  ) async {
    final highlighter = ShikiCodeHighlighter();
    await highlighter.highlight(
      source: _source(10000),
      language: 'dart',
      scheme: CodeHighlightScheme.dark,
    );

    final runs = <Map<String, Object?>>[];
    for (final characters in const [10000, 100000, 1000000]) {
      final source = _source(characters);
      final beforeRss = ProcessInfo.currentRss;
      final clock = Stopwatch()..start();
      final highlighting = await highlighter.highlight(
        source: source,
        language: 'dart',
        scheme: CodeHighlightScheme.dark,
      );
      clock.stop();
      runs.add({
        'source_characters': characters,
        'elapsed_us': clock.elapsedMicroseconds,
        'token_count': highlighting?.tokens.length,
        'rss_delta_bytes': ProcessInfo.currentRss - beforeRss,
      });
      expect(highlighting, isNotNull);
    }

    binding.reportData = {
      'benchmark': 'shiki_code_highlighting_scaling',
      'mode': 'profile',
      'runs': runs,
    };
  });
}

String _source(int characters) {
  const unit = 'final value = compute(input);\n';
  return (StringBuffer()
        ..writeAll(List.filled((characters / unit.length).ceil(), unit)))
      .toString()
      .substring(0, characters);
}
