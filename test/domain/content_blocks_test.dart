import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/domain/reading/content/block.dart';
import 'package:visualmd/domain/reading/content/inline.dart';

void main() {
  test('table text linearises rows and cells without losing boundaries', () {
    const table = TableBlock(
      head: [
        TableCell([TextRun('Metric')]),
        TableCell([TextRun('Value')]),
      ],
      rows: [
        [
          TableCell([TextRun('Revenue')]),
          TableCell([TextRun('1,234.50')]),
        ],
        [
          TableCell([TextRun('Margin')]),
          TableCell([]),
        ],
      ],
    );

    expect(table.text, 'Metric\tValue\nRevenue\t1,234.50\nMargin\t');
  });

  test('a themed image selects the first matching authored candidate', () {
    const image = ImageRun(
      source: 'fallback.png',
      alt: 'A system diagram',
      themedSources: [
        ThemedImageSource(
          scheme: ImageColorScheme.dark,
          source: 'dark-first.png',
        ),
        ThemedImageSource(
          scheme: ImageColorScheme.dark,
          source: 'dark-second.png',
        ),
      ],
    );

    expect(image.sourceFor(ImageColorScheme.dark), 'dark-first.png');
    expect(image.sourceFor(ImageColorScheme.light), 'fallback.png');
    expect(image.text, 'A system diagram');
  });
}
