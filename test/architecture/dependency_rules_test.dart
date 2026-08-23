// The dependency rules from docs/00-foundation/03-dependency-direction.md,
// enforced: every arrow in lib/ must point inward.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

enum Ring { domain, application, presentation, api, infrastructure, root }

Ring ringOf(String libRelativePath) {
  final top = libRelativePath.split('/').first;
  return switch (top) {
    'domain' => Ring.domain,
    'application' => Ring.application,
    'presentation' => Ring.presentation,
    'api' => Ring.api,
    'infrastructure' => Ring.infrastructure,
    _ => Ring.root,
  };
}

/// Rings that may not import any package: the domain, and the presentation
/// seams that themes are written against. Both must stay framework-free so a
/// contribution is data, never code.
const frameworkFreeRings = {Ring.domain, Ring.presentation};

/// Which rings each ring may import from.
const allowedRings = {
  Ring.domain: {Ring.domain},
  Ring.application: {Ring.application, Ring.domain},
  Ring.presentation: {Ring.presentation},
  Ring.api: {Ring.api, Ring.presentation, Ring.application, Ring.domain},
  Ring.infrastructure: {Ring.infrastructure, Ring.application, Ring.domain},
  Ring.root: {
    Ring.api,
    Ring.presentation,
    Ring.application,
    Ring.domain,
    Ring.infrastructure,
    Ring.root,
  },
};

/// Packages that touch the platform; only infrastructure may import them.
const platformPackages = {
  'web',
  'desktop_drop',
  'file_selector',
  'window_manager',
};

/// Dart SDK libraries that touch the platform; only infrastructure may import them.
const platformSdkLibraries = {'dart:io', 'dart:js_interop', 'dart:html'};

final importPattern = RegExp(
  r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''',
  multiLine: true,
);

String normalize(String from, String target) {
  final segments = from.split('/')..removeLast();
  for (final part in target.split('/')) {
    if (part == '..') {
      segments.removeLast();
    } else if (part != '.') {
      segments.add(part);
    }
  }
  return segments.join('/');
}

void main() {
  final libDir = Directory('lib');
  final files =
      libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .map((f) => f.path.substring('lib/'.length))
          .toList()
        ..sort();

  test('lib/ contains the expected rings and nothing else', () {
    final tops = files
        .map((f) => f.contains('/') ? f.split('/').first : f)
        .toSet();
    expect(tops, {
      'domain',
      'application',
      'presentation',
      'api',
      'infrastructure',
      'main.dart',
    });
  });

  for (final file in files) {
    final ring = ringOf(file);
    test('$file imports only inward (${ring.name})', () {
      final source = File('lib/$file').readAsStringSync();
      final violations = <String>[];
      for (final match in importPattern.allMatches(source)) {
        final target = match[1]!;
        if (target.startsWith('package:visualmd/')) {
          final other = ringOf(target.substring('package:visualmd/'.length));
          if (!allowedRings[ring]!.contains(other)) violations.add(target);
        } else if (target.startsWith('package:')) {
          final package = target.substring('package:'.length).split('/').first;
          if (frameworkFreeRings.contains(ring)) violations.add(target);
          if (platformPackages.contains(package) &&
              ring != Ring.infrastructure) {
            violations.add(target);
          }
        } else if (target.startsWith('dart:')) {
          if (platformSdkLibraries.contains(target) &&
              ring != Ring.infrastructure) {
            violations.add(target);
          }
        } else {
          final other = ringOf(normalize(file, target));
          if (!allowedRings[ring]!.contains(other)) violations.add(target);
        }
      }
      expect(violations, isEmpty, reason: 'outward imports in lib/$file');
    });
  }
}
