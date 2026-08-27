import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:visualmd/api/highlighting/shiki_code_highlighter.dart';
import 'package:visualmd/api/theme/library_theme.dart';
import 'package:visualmd/api/widgets/reading_pane.dart';
import 'package:visualmd/application/use_cases/read_document.dart';
import 'package:visualmd/domain/library/document.dart';
import 'package:visualmd/domain/library/document_id.dart';
import 'package:visualmd/domain/library/library_root_id.dart';
import 'package:visualmd/domain/reading/content/block.dart';
import 'package:visualmd/domain/reading/content/document_content.dart';
import 'package:visualmd/domain/reading/document_outline.dart';
import 'package:visualmd/infrastructure/viewport/quiet_document_viewport_geometry.dart';
import 'package:visualmd/presentation/code/code_highlighter.dart';
import 'package:visualmd/presentation/theme/built_in_themes.dart';
import 'package:visualmd/presentation/theme/reading_scale.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('large fences classify only their mounted source window', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final highlighter = _RecordingHighlighter(ShikiCodeHighlighter());
    await highlighter.highlight(
      source: _source(10000),
      language: 'dart',
      scheme: CodeHighlightScheme.dark,
    );
    highlighter.clear();

    final runs = <Map<String, Object?>>[];
    for (final characters in const [10000, 100000, 1000000]) {
      final beforeRss = ProcessInfo.currentRss;
      final beforeRequest = highlighter.requests.length;
      final clock = Stopwatch()..start();
      await tester.pumpWidget(
        _app(_reading(characters), highlighter: highlighter),
      );
      await tester.pumpAndSettle();
      await Future<void>.delayed(const Duration(milliseconds: 180));
      await tester.pumpAndSettle();
      clock.stop();

      final requests = highlighter.requests
          .skip(beforeRequest)
          .toList(growable: false);
      runs.add({
        'source_characters': characters,
        'request_count': requests.length,
        'maximum_request_characters': requests.fold<int>(
          0,
          (maximum, request) =>
              request.characters > maximum ? request.characters : maximum,
        ),
        'classification_elapsed_us': requests.fold<int>(
          0,
          (total, request) => total + request.elapsedUs,
        ),
        'returned_tokens': requests.fold<int>(
          0,
          (total, request) => total + request.tokens,
        ),
        'open_wall_us': clock.elapsedMicroseconds,
        'rss_delta_bytes': ProcessInfo.currentRss - beforeRss,
      });

      expect(requests, isNotEmpty);
      expect(
        requests.map((request) => request.characters),
        everyElement(lessThanOrEqualTo(32768)),
      );
      if (characters >= 32768) {
        expect(
          requests.map((request) => request.characters),
          everyElement(lessThan(10000)),
        );
      }
      expect(tester.takeException(), isNull);
    }

    binding.reportData = {
      'benchmark': 'windowed_shiki_highlighting_scaling',
      'mode': 'profile',
      'runs': runs,
    };
  });
}

final class _HighlightRequest {
  final int characters;
  final int elapsedUs;
  final int tokens;

  const _HighlightRequest({
    required this.characters,
    required this.elapsedUs,
    required this.tokens,
  });
}

final class _RecordingHighlighter implements CodeHighlighter {
  final CodeHighlighter delegate;
  final requests = <_HighlightRequest>[];

  _RecordingHighlighter(this.delegate);

  void clear() => requests.clear();

  @override
  String labelFor(String? language) => delegate.labelFor(language);

  @override
  Future<CodeHighlighting?> highlight({
    required String source,
    required String? language,
    required CodeHighlightScheme scheme,
  }) async {
    final clock = Stopwatch()..start();
    final result = await delegate.highlight(
      source: source,
      language: language,
      scheme: scheme,
    );
    clock.stop();
    requests.add(
      _HighlightRequest(
        characters: source.length,
        elapsedUs: clock.elapsedMicroseconds,
        tokens: result?.tokens.length ?? 0,
      ),
    );
    return result;
  }
}

Widget _app(DocumentReading reading, {required CodeHighlighter highlighter}) =>
    MaterialApp(
      theme: libraryTheme(BuiltInThemes.paper),
      home: Scaffold(
        body: ReadingPane(
          reading: reading,
          scale: ReadingScale.comfortable,
          codeHighlighter: highlighter,
          viewportGeometry: const QuietDocumentViewportGeometryFactory(),
          onLink: (_) {},
          onActiveHeadingChanged: (_) {},
        ),
      ),
    );

DocumentReading _reading(int characters) {
  final source = _source(characters);
  final documentSource = '```dart\n$source\n```';
  return DocumentReading(
    document: Document(
      id: DocumentId(
        const LibraryRootId('windowed-highlighting-benchmark'),
        'source-$characters.md',
      ),
      content: documentSource,
      title: 'Windowed highlighting benchmark',
    ),
    source: documentSource,
    outline: DocumentOutline.parse(''),
    content: DocumentContent([CodeBlock(code: source, language: 'dart')]),
  );
}

String _source(int characters) {
  const unit = 'final value = compute(input);\n';
  return (StringBuffer()
        ..writeAll(List.filled((characters / unit.length).ceil(), unit)))
      .toString()
      .substring(0, characters);
}
