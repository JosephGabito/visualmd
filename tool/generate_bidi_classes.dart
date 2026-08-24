import 'dart:io';
import 'dart:typed_data';

const _unicodeVersion = '17.0.0';
const _source =
    'https://www.unicode.org/Public/$_unicodeVersion/ucd/extracted/'
    'DerivedBidiClass.txt';
const _output = 'lib/api/render/strong_bidi_classes.g.dart';

Future<void> main(List<String> arguments) async {
  final check = arguments.contains('--check');
  final client = HttpClient();

  try {
    final request = await client.getUrl(Uri.parse(_source));
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      stderr.writeln('$_source returned HTTP ${response.statusCode}.');
      exitCode = 1;
      return;
    }

    final lines = await response
        .transform(const SystemEncoding().decoder)
        .join();
    final classes = Uint8List(0x110000)..fillRange(0, 0x110000, _ltr);

    // UCD @missing declarations establish defaults for unlisted code points.
    // The broad default appears first; later script-specific defaults refine it.
    for (final line in lines.split('\n')) {
      final match = _missing.firstMatch(line);
      if (match == null) continue;
      _fill(classes, match, _valueOf(match[3]!));
    }

    // Explicit records override those defaults, including neutral and weak
    // classes which must not accidentally become strong LTR characters.
    for (final line in lines.split('\n')) {
      final match = _record.firstMatch(line);
      if (match == null) continue;
      _fill(classes, match, _valueOf(match[3]!));
    }

    final ranges = <(int, int, int)>[];
    var start = 0;
    var value = classes.first;
    for (var codePoint = 1; codePoint < classes.length; codePoint++) {
      if (classes[codePoint] == value) continue;
      if (value != _neutral) ranges.add((start, codePoint - 1, value));
      start = codePoint;
      value = classes[codePoint];
    }
    if (value != _neutral) ranges.add((start, classes.length - 1, value));

    final generated = _render(ranges);
    final output = File(_output);
    if (check) {
      if (!output.existsSync() || output.readAsStringSync() != generated) {
        stderr.writeln(
          '$_output is stale. Run dart run tool/generate_bidi_classes.dart.',
        );
        exitCode = 1;
      }
      return;
    }

    output.writeAsStringSync(generated);
    stdout.writeln('Wrote ${ranges.length} strong ranges to $_output.');
  } finally {
    client.close(force: true);
  }
}

const _neutral = 0;
const _ltr = 1;
const _rtl = 2;

final _missing = RegExp(
  r'^# @missing: ([0-9A-F]+)(?:\.\.([0-9A-F]+))?; ([A-Za-z_]+)',
);
final _record = RegExp(r'^([0-9A-F]+)(?:\.\.([0-9A-F]+))?\s*;\s*([A-Za-z_]+)');

void _fill(Uint8List classes, RegExpMatch match, int value) {
  final start = int.parse(match[1]!, radix: 16);
  final end = int.parse(match[2] ?? match[1]!, radix: 16);
  classes.fillRange(start, end + 1, value);
}

int _valueOf(String bidiClass) => switch (bidiClass) {
  'L' || 'Left_To_Right' => _ltr,
  'R' || 'Right_To_Left' || 'AL' || 'Arabic_Letter' => _rtl,
  _ => _neutral,
};

String _render(List<(int, int, int)> ranges) {
  final output = StringBuffer()
    ..writeln('// Generated file. Do not edit.')
    ..writeln('//')
    ..writeln('// Unicode: $_unicodeVersion')
    ..writeln('// Source: $_source')
    ..writeln('// Script: tool/generate_bidi_classes.dart')
    ..writeln()
    ..writeln('abstract final class StrongBidiClasses {')
    ..writeln('  static const none = 0;')
    ..writeln('  static const ltr = 1;')
    ..writeln('  static const rtl = 2;')
    ..writeln()
    ..writeln('  static int of(int codePoint) {')
    ..writeln('    var low = 0;')
    ..writeln('    var high = _ranges.length ~/ 3 - 1;')
    ..writeln('    while (low <= high) {')
    ..writeln('      final middle = (low + high) >> 1;')
    ..writeln('      final index = middle * 3;')
    ..writeln('      final start = _ranges[index];')
    ..writeln('      final end = _ranges[index + 1];')
    ..writeln('      if (codePoint < start) {')
    ..writeln('        high = middle - 1;')
    ..writeln('      } else if (codePoint > end) {')
    ..writeln('        low = middle + 1;')
    ..writeln('      } else {')
    ..writeln('        return _ranges[index + 2];')
    ..writeln('      }')
    ..writeln('    }')
    ..writeln('    return none;')
    ..writeln('  }')
    ..writeln()
    ..writeln('  static const _ranges = <int>[');

  for (final (start, end, value) in ranges) {
    output
      ..writeln('    0x${start.toRadixString(16)},')
      ..writeln('    0x${end.toRadixString(16)},')
      ..writeln('    $value,');
  }

  return (output
        ..writeln('  ];')
        ..writeln('}'))
      .toString();
}
