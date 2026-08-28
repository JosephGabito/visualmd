import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/api/render/geometry_sliver_list.dart';
import 'package:visualmd/application/ports/document_viewport_geometry.dart';
import 'package:visualmd/domain/reading/content/document_content.dart';
import 'package:visualmd/infrastructure/viewport/quiet_document_viewport_geometry.dart';

void main() {
  const factory = QuietDocumentViewportGeometryFactory();

  testWidgets('a distant block is reached without building its prefix', (
    tester,
  ) async {
    const count = 5000;
    final geometry = factory.create()
      ..appendAll([
        for (var index = 0; index < count; index++) _seed(index, 40),
      ]);
    final controller = ScrollController();
    final built = <int>[];

    await tester.pumpWidget(
      _Viewport(
        controller: controller,
        child: GeometrySliverList.builder(
          viewportGeometry: geometry,
          layoutRevision: 0,
          itemCount: count,
          seedAt: (index) => _seed(index, 40),
          indexOf: (id) => int.parse(id.value.substring(6)),
          itemBuilder: (context, index) {
            built.add(index);
            return SizedBox(
              key: ValueKey('item-$index'),
              height: 40,
              child: Text('$index'),
            );
          },
        ),
      ),
    );

    built.clear();
    controller.jumpTo(4000 * 40);
    await tester.pump();

    expect(find.byKey(const ValueKey('item-4000')), findsOneWidget);
    expect(built.length, lessThan(40));
    expect(built, isNot(contains(0)));
  });

  testWidgets('better estimates correct the anchor before it is painted', (
    tester,
  ) async {
    const count = 500;
    const anchor = 100;
    final geometry = factory.create()
      ..appendAll([
        for (var index = 0; index < count; index++) _seed(index, 40),
      ]);
    final controller = ScrollController(initialScrollOffset: anchor * 40);
    final corrections = <DocumentExtentCorrection>[];

    await tester.pumpWidget(
      _Viewport(
        controller: controller,
        child: GeometrySliverList.builder(
          viewportGeometry: geometry,
          layoutRevision: 0,
          itemCount: count,
          seedAt: (index) => _seed(index, 40),
          indexOf: (id) => int.parse(id.value.substring(6)),
          onExtentCorrection: corrections.add,
          itemBuilder: (context, index) => SizedBox(
            key: ValueKey('item-$index'),
            height: 80,
            child: Text('$index'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('item-100')), findsOneWidget);
    expect(tester.getTopLeft(find.byKey(const ValueKey('item-100'))).dy, 0);
    expect(controller.offset, greaterThan(anchor * 40));
    expect(corrections.any((value) => value.scrollOffsetDelta > 0), isTrue);
  });

  testWidgets('a layout epoch changes scale without moving the anchor', (
    tester,
  ) async {
    const count = 500;
    const anchor = 100;
    final geometry = factory.create()
      ..appendAll([
        for (var index = 0; index < count; index++) _seed(index, 40),
      ]);
    final controller = ScrollController(initialScrollOffset: anchor * 40);

    Future<void> show(int revision, double extent) => tester.pumpWidget(
      _Viewport(
        controller: controller,
        child: GeometrySliverList.builder(
          viewportGeometry: geometry,
          layoutRevision: revision,
          layoutScale: extent / 40,
          itemCount: count,
          seedAt: (index) => _seed(index, extent),
          indexOf: (id) => int.parse(id.value.substring(6)),
          itemBuilder: (context, index) => SizedBox(
            key: ValueKey('item-$index'),
            height: extent,
            child: Text('$index'),
          ),
        ),
      ),
    );

    await show(0, 40);
    await tester.pumpAndSettle();
    final target = find.byKey(const ValueKey('item-100'));
    final beforeTop = tester.getTopLeft(target).dy;

    await show(1, 80);
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(target).dy, closeTo(beforeTop, 0.01));
    expect(controller.offset, closeTo(anchor * 80, 0.01));
  });

  testWidgets('a collapsing tail estimate is corrected before paint', (
    tester,
  ) async {
    const count = 60;
    DocumentExtentSeed seedAt(int index) =>
        _seed(index, index == 50 ? 5000 : 40);
    final geometry = factory.create()
      ..appendAll([for (var index = 0; index < count; index++) seedAt(index)]);
    final controller = ScrollController();

    await tester.pumpWidget(
      _Viewport(
        controller: controller,
        child: GeometrySliverList.builder(
          viewportGeometry: geometry,
          layoutRevision: 0,
          itemCount: count,
          seedAt: seedAt,
          indexOf: (id) => int.parse(id.value.substring(6)),
          itemBuilder: (context, index) => SizedBox(
            key: ValueKey('item-$index'),
            height: 40,
            child: Text('$index'),
          ),
        ),
      ),
    );

    expect(controller.position.maxScrollExtent, greaterThan(5000));
    controller.jumpTo(5000);
    await tester.pump();

    expect(_paintedItemCount(tester), greaterThan(0));
    expect(controller.offset, lessThan(geometry.totalExtent));
  });
}

int _paintedItemCount(WidgetTester tester) {
  const viewport = Rect.fromLTWH(0, 0, 800, 600);
  final items = find.byWidgetPredicate((widget) {
    final key = widget.key;
    return key is ValueKey<String> && key.value.startsWith('item-');
  }, skipOffstage: false);
  var visible = 0;
  for (final element in items.evaluate()) {
    final box = element.renderObject;
    if (box is! RenderBox || !box.attached || !box.hasSize) continue;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    if (rect.overlaps(viewport)) visible++;
  }
  return visible;
}

DocumentExtentSeed _seed(int index, double extent) => DocumentExtentSeed(
  id: DocumentBlockId('block:$index'),
  revision: 0,
  estimatedExtent: extent,
);

final class _Viewport extends StatelessWidget {
  const _Viewport({required this.controller, required this.child});

  final ScrollController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: SizedBox(
      width: 800,
      height: 600,
      child: CustomScrollView(controller: controller, slivers: [child]),
    ),
  );
}
