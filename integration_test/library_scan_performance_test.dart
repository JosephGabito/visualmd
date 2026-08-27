import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:visualmd/infrastructure/io/local_folder.dart';
import 'package:visualmd/infrastructure/io/local_folder_scanner.dart';

/// Measures the desktop path from a real directory to visible shelf metadata,
/// then the deferred authored-title pass.
///
/// Fixture creation is deliberately outside the timed region. The scan itself
/// uses the production directory walker, UTF-8 decoder, title extraction, and
/// physical source identity. Reporting the phases separately protects the
/// first-visible-shelf contract from being hidden inside one total.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('folder opening exposes its document-count slope', (
    tester,
  ) async {
    final fixture = await Directory.systemTemp.createTemp(
      'visualmd-library-benchmark-',
    );
    addTearDown(() => fixture.delete(recursive: true));
    final runs = <Map<String, Object?>>[];

    for (final documentCount in const [100, 1000, 5000]) {
      final root = Directory('${fixture.path}/library-$documentCount');
      await root.create();
      const padding =
          'A quiet Markdown library should appear without waiting for every '
          'book to be read in full. ';
      for (var index = 0; index < documentCount; index++) {
        final folder = Directory('${root.path}/section-${index ~/ 100}');
        await folder.create();
        await File('${folder.path}/document-$index.md').writeAsString(
          '# Document $index\n\n${List.filled(12, padding).join()}',
        );
      }

      final registry = LocalFolderRegistry('library-scan-benchmark');
      final ref = registry.register('library', LocalDirectory(root.path));
      final scanner = LocalFolderScanner(registry);
      final beforeRss = ProcessInfo.currentRss;
      final metadataClock = Stopwatch()..start();
      final metadata = await scanner.scanMetadata(ref);
      metadataClock.stop();
      final enrichmentClock = Stopwatch()..start();
      final enriched = await scanner.enrichTitles(ref, metadata);
      enrichmentClock.stop();
      final totalElapsed =
          metadataClock.elapsedMicroseconds +
          enrichmentClock.elapsedMicroseconds;

      runs.add({
        'documents': documentCount,
        'source_bytes': await _sourceBytes(root),
        'metadata_elapsed_us': metadataClock.elapsedMicroseconds,
        'title_enrichment_elapsed_us': enrichmentClock.elapsedMicroseconds,
        'elapsed_us': totalElapsed,
        'rss_delta_bytes': ProcessInfo.currentRss - beforeRss,
        'indexed_titles': enriched.files
            .where((file) => file.title != null)
            .length,
      });
      expect(metadata.files, hasLength(documentCount));
      expect(metadata.files.every((file) => file.title == null), isTrue);
      expect(enriched.files, hasLength(documentCount));
    }

    binding.reportData = {
      'benchmark': 'local_library_scan_scaling',
      'mode': 'profile',
      'runs': runs,
    };
  });
}

Future<int> _sourceBytes(Directory root) async {
  var bytes = 0;
  await for (final entity in root.list(recursive: true, followLinks: false)) {
    if (entity is File) bytes += await entity.length();
  }
  return bytes;
}
