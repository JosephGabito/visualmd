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
}
