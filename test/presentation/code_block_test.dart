import 'package:flutter/material.dart' hide TableCell;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/api/render/document_view.dart';
import 'package:visualmd/api/render/reading_theme.dart';
import 'package:visualmd/api/theme/library_theme.dart';
import 'package:visualmd/api/widgets/code_block.dart';
import 'package:visualmd/domain/reading/content/block.dart';
import 'package:visualmd/domain/reading/content/document_content.dart';
import 'package:visualmd/presentation/theme/built_in_themes.dart';
import 'package:visualmd/presentation/theme/reading_scale.dart';

const _longLine =
    'final library = LibraryBuilder.build(name: "notes", files: files, extra: 1);';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    for (final entry in {
      'Alegreya': 'assets/fonts/Alegreya.ttf',
      'Literata': 'assets/fonts/Literata.ttf',
      'Inter': 'assets/fonts/Inter.ttf',
      'JetBrains Mono': 'assets/fonts/JetBrainsMono.ttf',
    }.entries) {
      await (FontLoader(
        entry.key,
      )..addFont(rootBundle.load(entry.value))).load();
    }
  });

  Future<void> pumpCode(
    WidgetTester tester,
    String code, {
    double width = 520,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: libraryTheme(BuiltInThemes.paper),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: Builder(
                builder: (context) {
                  return DocumentView(
                    content: DocumentContent([CodeBlock(code: code)]),
                    theme: ReadingTheme.of(context, ReadingScale.comfortable),
                    anchorKeys: {},
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  ScrollPosition positionOf(WidgetTester tester) =>
      tester.widget<Scrollable>(find.byType(Scrollable)).controller!.position;

  testWidgets('a long line scrolls sideways instead of being cut off', (
    tester,
  ) async {
    await pumpCode(tester, _longLine);

    final position = positionOf(tester);
    expect(position.axis, Axis.horizontal);
    expect(
      position.maxScrollExtent,
      greaterThan(0),
      reason: 'the line is longer than the column, so there must be somewhere to scroll',
    );

    position.jumpTo(position.maxScrollExtent);
    await tester.pump();
    expect(find.textContaining('extra: 1'), findsOneWidget);
    expect(
      tester.widget<Scrollbar>(find.byType(Scrollbar)).thumbVisibility,
      isTrue,
    );
  });

  testWidgets('code is never re-wrapped, which would change what it says', (
    tester,
  ) async {
    await pumpCode(tester, _longLine);
    expect(
      tester.widget<Text>(find.textContaining('LibraryBuilder')).softWrap,
      isFalse,
    );
  });

  testWidgets('code is never re-punctuated either', (tester) async {
    await pumpCode(tester, 'git log --oneline "HEAD"...');
    expect(find.text('git log --oneline "HEAD"...'), findsOneWidget);
  });

  testWidgets('a short block needs no scrolling but still fills its column', (
    tester,
  ) async {
    await pumpCode(tester, 'ok');
    expect(positionOf(tester).maxScrollExtent, 0);
    expect(
      tester.getSize(find.byType(ReadableCodeBlock)).width,
      greaterThan(300),
      reason:
          'the block is a band across the page, not a label around the word',
    );
  });
}
