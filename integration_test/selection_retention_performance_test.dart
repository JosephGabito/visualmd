import 'dart:io';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:visualmd/api/render/document_view.dart';
import 'package:visualmd/api/theme/library_theme.dart';
import 'package:visualmd/api/widgets/reading_pane.dart';
import 'package:visualmd/application/use_cases/read_document.dart';
import 'package:visualmd/domain/library/document.dart';
import 'package:visualmd/domain/library/document_id.dart';
import 'package:visualmd/domain/library/library_root_id.dart';
import 'package:visualmd/domain/reading/content/block.dart';
import 'package:visualmd/domain/reading/content/document_content.dart';
import 'package:visualmd/domain/reading/content/inline.dart';
import 'package:visualmd/domain/reading/document_outline.dart';
import 'package:visualmd/infrastructure/viewport/quiet_document_viewport_geometry.dart';
import 'package:visualmd/presentation/theme/built_in_themes.dart';
import 'package:visualmd/presentation/theme/reading_scale.dart';

/// Proves a pointer selection crosses a lazy document without retaining its
/// render trail.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('drag selection exposes retained block scaling', (tester) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final runs = <Map<String, Object?>>[];

    const blocks = 5000;
    for (final frameBudget in const [60, 180, 360]) {
      await tester.pumpWidget(_app(_reading(blocks)));
      await tester.pumpAndSettle();
      final scrollable = find.descendant(
        of: find.byType(CustomScrollView),
        matching: find.byType(Scrollable),
      );
      final position = tester.state<ScrollableState>(scrollable).position;
      final start =
          tester.getTopLeft(find.byType(Paragraph).first) +
          const Offset(32, 18);
      final beforeRss = ProcessInfo.currentRss;
      final gesture = await tester.startGesture(
        start,
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveTo(Offset(start.dx, 900));
      await tester.pump();

      final clock = Stopwatch()..start();
      var selectionFrames = 0;
      while (selectionFrames < frameBudget) {
        await tester.pump(const Duration(milliseconds: 16));
        selectionFrames++;
      }
      await gesture.up();
      await tester.pumpAndSettle();
      clock.stop();
      final selectionContext = tester.element(find.byType(Paragraph).first);
      Actions.invoke(selectionContext, CopySelectionTextIntent.copy);
      await tester.pump();
      final copied = await Clipboard.getData(Clipboard.kTextPlain);

      runs.add({
        'document_blocks': blocks,
        'drag_frame_budget': frameBudget,
        'mounted_paragraphs': find.byType(Paragraph).evaluate().length,
        'retained_paragraphs': find
            .byType(Paragraph, skipOffstage: false)
            .evaluate()
            .length,
        'selection_wall_us': clock.elapsedMicroseconds,
        'selection_frames': selectionFrames,
        'rss_delta_bytes': ProcessInfo.currentRss - beforeRss,
        'final_scroll_pixels': position.pixels,
        'copied_characters': copied?.text?.length ?? 0,
      });
      expect(position.pixels, greaterThan(0));
      expect(
        find.byType(Paragraph, skipOffstage: false).evaluate().length,
        lessThanOrEqualTo(24),
        reason: 'selection must not retain one paragraph per crossed block',
      );
      if (runs.length > 1) {
        expect(
          copied?.text?.length ?? 0,
          greaterThan(runs[runs.length - 2]['copied_characters']! as int),
          reason: 'copy must still include the newly crossed document range',
        );
      }
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }

    binding.reportData = {
      'benchmark': 'selection_retention_scaling',
      'mode': 'profile',
      'runs': runs,
    };
  });
}

Widget _app(DocumentReading reading) => MaterialApp(
  theme: libraryTheme(BuiltInThemes.paper),
  home: Scaffold(
    body: ReadingPane(
      reading: reading,
      scale: ReadingScale.comfortable,
      viewportGeometry: const QuietDocumentViewportGeometryFactory(),
      onLink: (_) {},
      onActiveHeadingChanged: (_) {},
    ),
  ),
);

DocumentReading _reading(int count) {
  final id = DocumentId(const LibraryRootId('selection'), 'selection.md');
  final entries = List<DocumentBlock>.unmodifiable([
    for (var index = 0; index < count; index++)
      DocumentBlock(
        id: DocumentBlockId('paragraph-$index'),
        revision: 0,
        block: ParagraphBlock([
          TextRun(
            'Paragraph $index has enough stable text to expose how native '
            'selection retains lazy document blocks while crossing them.',
          ),
        ]),
      ),
  ]);
  final content = DocumentContent.revisioned(entries);
  return DocumentReading(
    document: Document(id: id, content: content.text, title: 'Selection'),
    source: content.text,
    outline: DocumentOutline.parse(''),
    content: content,
  );
}
