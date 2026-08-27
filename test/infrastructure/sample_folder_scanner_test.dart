import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/infrastructure/memory/sample_folder_scanner.dart';

void main() {
  test(
    'the public sample library contains no placeholder destinations',
    () async {
      final scanned = await SampleFolderScanner().scan(SampleFolderScanner.ref);
      final source = scanned.files.map((file) => file.content ?? '').join('\n');

      expect(
        source,
        isNot(
          matches(
            RegExp(
              r'https?://(?:[^/\s)]+\.invalid|(?:www\.)?example\.(?:com|org|net))(?:[/\s)]|$)',
              caseSensitive: false,
            ),
          ),
        ),
      );
    },
  );
}
