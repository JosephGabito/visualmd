import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/api/render/reading_theme.dart';
import 'package:visualmd/api/theme/library_theme.dart';
import 'package:visualmd/api/widgets/document_image.dart';
import 'package:visualmd/application/ports/document_image_loader.dart';
import 'package:visualmd/domain/library/document_id.dart';
import 'package:visualmd/domain/library/library_root_id.dart';
import 'package:visualmd/presentation/theme/built_in_themes.dart';
import 'package:visualmd/presentation/theme/reading_scale.dart';

final _document = DocumentId(const LibraryRootId('notes'), 'guide/page.md');

final class _Loader implements DocumentImageLoader {
  final Uint8List? bytes;
  final List<(DocumentId, String)> calls = [];

  _Loader(this.bytes);

  @override
  Future<Uint8List?> load(DocumentId document, String source) async {
    calls.add((document, source));
    return bytes;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpImage(
    WidgetTester tester, {
    required String source,
    required String alt,
    String? title,
    DocumentImageLoader? loader,
    double width = 180,
    bool settle = true,
  }) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: libraryTheme(BuiltInThemes.paper),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: Align(
                alignment: Alignment.topLeft,
                child: Builder(
                  builder: (context) => DocumentImage(
                    document: _document,
                    source: source,
                    alt: alt,
                    title: title,
                    loader: loader,
                    theme: ReadingTheme.of(context, ReadingScale.comfortable),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }

  Future<void> decodeRenderedImage(WidgetTester tester) async {
    final provider = tester.widget<Image>(find.byType(Image)).image;
    await tester.runAsync(() async {
      final decoded = Completer<void>();
      final stream = provider.resolve(ImageConfiguration.empty);
      late final ImageStreamListener listener;
      listener = ImageStreamListener(
        (_, _) {
          if (!decoded.isCompleted) decoded.complete();
          stream.removeListener(listener);
        },
        onError: (Object error, StackTrace? stackTrace) {
          if (!decoded.isCompleted) decoded.completeError(error, stackTrace);
          stream.removeListener(listener);
        },
      );
      stream.addListener(listener);
      await decoded.future;
    });
    await tester.pump();
  }

  testWidgets('small artwork keeps its intrinsic size', (tester) async {
    final pixel = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    );
    await pumpImage(
      tester,
      source: 'pixel.png',
      alt: 'One pixel',
      loader: _Loader(pixel),
    );
    await decodeRenderedImage(tester);

    expect(tester.getSize(find.byType(Image)), const Size(1, 1));
    final componentHeight = tester.getSize(find.byType(DocumentImage)).height;
    final baseline = ReadingTheme.of(
      tester.element(find.byType(DocumentImage)),
      ReadingScale.comfortable,
    ).baseline;
    expect(
      componentHeight / baseline,
      closeTo((componentHeight / baseline).round(), 0.001),
    );
  });

  testWidgets('oversized artwork shrinks to the reading column', (
    tester,
  ) async {
    final data = await rootBundle.load('assets/brand/visual-md-logo.png');
    final loader = _Loader(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
    await pumpImage(
      tester,
      source: '../images/visual-md-logo.png',
      alt: 'Visual MD',
      title: 'Open-book mark',
      loader: loader,
    );
    await decodeRenderedImage(tester);

    expect(tester.getSize(find.byType(Image)), const Size(180, 180));
    expect(
      tester.widget<Tooltip>(find.byType(Tooltip)).message,
      'Open-book mark',
    );
    expect(loader.calls, [(_document, '../images/visual-md-logo.png')]);
  });

  testWidgets('bad bytes leave the authored alternative on the page', (
    tester,
  ) async {
    await pumpImage(
      tester,
      source: 'broken.png',
      alt: 'A system diagram',
      loader: _Loader(Uint8List.fromList([1, 2, 3])),
    );

    expect(find.text('A system diagram'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('remote artwork uses the cross-origin fallback path', (
    tester,
  ) async {
    final loader = _Loader(null);
    await pumpImage(
      tester,
      source: 'https://example.com/diagram.png',
      alt: 'Remote diagram',
      loader: loader,
      settle: false,
    );

    final image = tester.widget<Image>(find.byType(Image));
    final provider = (image.image as ResizeImage).imageProvider as NetworkImage;
    expect(provider.url, 'https://example.com/diagram.png');
    expect(provider.webHtmlElementStrategy, WebHtmlElementStrategy.fallback);
    expect(loader.calls, isEmpty);
  });

  testWidgets('empty alternative text makes successful art decorative', (
    tester,
  ) async {
    final pixel = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    );
    await pumpImage(
      tester,
      source: 'flourish.png',
      alt: '',
      loader: _Loader(pixel),
    );
    await decodeRenderedImage(tester);

    expect(
      tester.widget<Image>(find.byType(Image)).excludeFromSemantics,
      isTrue,
    );
  });

  testWidgets('empty alternatives stay decorative while loading', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpImage(
      tester,
      source: 'flourish.png',
      alt: '',
      loader: _Loader(null),
      settle: false,
    );

    expect(find.text('Loading image'), findsOneWidget);
    expect(find.bySemanticsLabel('Loading image'), findsNothing);
    semantics.dispose();
  });

  testWidgets('empty alternatives stay decorative after failure', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpImage(
      tester,
      source: 'broken.png',
      alt: '',
      loader: _Loader(Uint8List.fromList([1, 2, 3])),
    );

    expect(find.text('Image unavailable'), findsOneWidget);
    expect(find.bySemanticsLabel('Image unavailable'), findsNothing);
    semantics.dispose();
  });

  testWidgets('a selected-source change begins one new local image load', (
    tester,
  ) async {
    final pixel = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    );
    final loader = _Loader(pixel);

    await pumpImage(
      tester,
      source: 'light.png',
      alt: 'A themed diagram',
      loader: loader,
    );
    await pumpImage(
      tester,
      source: 'dark.png',
      alt: 'A themed diagram',
      loader: loader,
    );

    expect(loader.calls, [(_document, 'light.png'), (_document, 'dark.png')]);
  });
}
