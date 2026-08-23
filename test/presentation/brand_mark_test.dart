import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/api/widgets/brand_mark.dart';

void main() {
  testWidgets(
    'the product mark uses the shipped artwork at its requested size',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Center(child: BrandMark(size: 64))),
      );

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.image, isA<AssetImage>());
      expect((image.image as AssetImage).assetName, BrandMark.assetName);
      expect(image.width, 64);
      expect(image.height, 64);
      expect(image.excludeFromSemantics, isTrue);
    },
  );
}
