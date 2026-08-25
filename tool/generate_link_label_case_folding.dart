import 'dart:convert';
import 'dart:io';

import 'package:markdown/src/assets/case_folding.dart';

/// Keeps the framework-free outline's label matching identical to the
/// markdown package that resolves links for the page.
void main() {
  final output = StringBuffer()
    ..writeln('// Generated file. Do not edit.')
    ..writeln('//')
    ..writeln('// Source: package:markdown case_folding.dart')
    ..writeln('// Script: tool/generate_link_label_case_folding.dart')
    ..writeln('// ignore_for_file: prefer_single_quotes')
    ..writeln()
    ..write('const linkLabelCaseFolding = ')
    ..write(const JsonEncoder.withIndent('  ').convert(caseFoldingMap))
    ..writeln(';');

  File('lib/domain/reading/link_label_case_folding.g.dart')
      .writeAsStringSync(output.toString());
}
