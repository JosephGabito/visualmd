import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/application/ports/document_image_loader.dart';

void main() {
  test('an image path begins beside the markdown document', () {
    expect(
      DocumentImagePath.resolve(
        documentPath: 'guide/chapters/intro.md',
        source: 'figures/map.png',
      ),
      'guide/chapters/figures/map.png',
    );
    expect(
      DocumentImagePath.resolve(
        documentPath: 'guide/chapters/intro.md',
        source: '../shared/map.png',
      ),
      'guide/shared/map.png',
    );
  });

  test('URL spelling is decoded without treating its query as a file name', () {
    expect(
      DocumentImagePath.resolve(
        documentPath: 'guide/intro.md',
        source: 'art/a%20quiet%20map.png?raw=1#preview',
      ),
      'guide/art/a quiet map.png',
    );
    expect(
      DocumentImagePath.resolve(
        documentPath: r'guide\intro.md',
        source: r'art\map.png',
      ),
      'guide/art/map.png',
    );
  });

  test('a document image can never escape the opened folder', () {
    for (final source in [
      '../../secret.png',
      '/absolute.png',
      r'C:\absolute.png',
      '//server/share.png',
      'file:///secret.png',
      'https://example.com/image.png',
      'images%2Fsecret.png',
      'images%5Csecret.png',
    ]) {
      expect(
        DocumentImagePath.resolve(
          documentPath: 'guide/intro.md',
          source: source,
        ),
        isNull,
        reason: source,
      );
    }
  });
}
