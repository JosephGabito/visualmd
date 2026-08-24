import 'dart:convert';
import 'dart:io';

const _source = 'https://html.spec.whatwg.org/entities.json';
const _output = 'lib/domain/reading/named_character_references.g.dart';

Future<void> main(List<String> arguments) async {
  final check = arguments.contains('--check');
  final client = HttpClient();

  try {
    final request = await client.getUrl(Uri.parse(_source));
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      stderr.writeln('$_source returned HTTP ${response.statusCode}.');
      exitCode = 1;
      return;
    }

    final json = jsonDecode(await utf8.decodeStream(response));
    if (json is! Map<String, dynamic>) {
      stderr.writeln('$_source did not contain an object.');
      exitCode = 1;
      return;
    }

    final names = json.entries.where((entry) => entry.key.endsWith(';')).map((
      entry,
    ) {
      final value = entry.value;
      if (value is! Map<String, dynamic> || value['characters'] is! String) {
        throw FormatException('Missing characters for ${entry.key}.');
      }
      return MapEntry(entry.key, value['characters']! as String);
    }).toList()..sort((left, right) => left.key.compareTo(right.key));

    final generated = _render(names);
    final output = File(_output);
    if (check) {
      if (!output.existsSync() || output.readAsStringSync() != generated) {
        stderr.writeln(
          '$_output is stale. Run dart run '
          'tool/generate_character_references.dart.',
        );
        exitCode = 1;
      }
      return;
    }

    output.writeAsStringSync(generated);
    stdout.writeln('Wrote ${names.length} names to $_output.');
  } finally {
    client.close(force: true);
  }
}

String _render(List<MapEntry<String, String>> names) {
  final output = StringBuffer()
    ..writeln('// Generated file. Do not edit.')
    ..writeln('//')
    ..writeln('// Source: $_source')
    ..writeln('// Script: tool/generate_character_references.dart')
    ..writeln('// ignore_for_file: prefer_single_quotes')
    ..writeln()
    ..writeln('const namedCharacterReferences = <String, String>{');

  for (final name in names) {
    output
      ..write('  ')
      ..write(_dartString(name.key))
      ..write(': ')
      ..write(_dartString(name.value))
      ..writeln(',');
  }

  return (output..writeln('};')).toString();
}

String _dartString(String value) => jsonEncode(value).replaceAll(r'$', r'\$');
