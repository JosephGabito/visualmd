import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every bundled face carries designed scientific positions', () {
    final fonts =
        Directory('assets/fonts')
            .listSync()
            .whereType<File>()
            .where((file) => file.path.endsWith('.ttf'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    expect(fonts, isNotEmpty);
    for (final font in fonts) {
      final gsub = _table(font.readAsBytesSync(), 'GSUB');
      expect(gsub, isNotNull, reason: '${font.path} has no GSUB table');
      final features = _nonEmptyFeatures(gsub!);
      expect(
        features,
        contains('subs'),
        reason: '${font.path} has no subscript feature',
      );
      expect(
        features,
        contains('sups'),
        reason: '${font.path} has no superscript feature',
      );
    }
  });
}

Uint8List? _table(Uint8List font, String wanted) {
  final data = ByteData.sublistView(font);
  final count = data.getUint16(4);
  for (var index = 0; index < count; index++) {
    final record = 12 + index * 16;
    final tag = ascii.decode(font.sublist(record, record + 4));
    if (tag != wanted) continue;
    final offset = data.getUint32(record + 8);
    final length = data.getUint32(record + 12);
    return Uint8List.sublistView(font, offset, offset + length);
  }
  return null;
}

Set<String> _nonEmptyFeatures(Uint8List gsub) {
  final data = ByteData.sublistView(gsub);
  final featureList = data.getUint16(6);
  final count = data.getUint16(featureList);
  final features = <String>{};
  for (var index = 0; index < count; index++) {
    final record = featureList + 2 + index * 6;
    final tag = ascii.decode(gsub.sublist(record, record + 4));
    final feature = featureList + data.getUint16(record + 4);
    final lookupCount = data.getUint16(feature + 2);
    if (lookupCount > 0) features.add(tag);
  }
  return features;
}
