// Opens docs/ through the app's own domain code and checks that it holds
// together: links resolve, anchors exist, every shelf has a README, every
// document has a title, and every source reference points at a real file.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/domain/library/document.dart';
import 'package:visualmd/domain/library/document_id.dart';
import 'package:visualmd/domain/library/folder.dart';
import 'package:visualmd/domain/library/library.dart';
import 'package:visualmd/domain/library/library_builder.dart';
import 'package:visualmd/domain/library/library_root_id.dart';
import 'package:visualmd/infrastructure/io/local_folder.dart';
import 'package:visualmd/infrastructure/io/local_folder_scanner.dart';

final linkPattern = RegExp(r'(?<!!)\[[^\]]*\]\(([^)\s]+)\)');
final sourceReferencePattern = RegExp(
  r'`((?:(?:lib|test|macos|web|windows|docs|tool|bin)/[\w./@-]+\.\w+|(?:pubspec|analysis_options)\.yaml|README\.md))`',
);
final lineCitationPattern = RegExp(
  r'`(?:(?:(?:lib|test|macos|web|windows|docs|tool|bin)/[\w./@-]+\.\w+|(?:pubspec|analysis_options)\.yaml|README\.md))?:\d+(?:-\d+)?(?:,\d+(?:-\d+)?)*`',
);
final fencePattern = RegExp(r'^ {0,3}(`{3,}|~{3,})', multiLine: true);

/// Strips fenced code blocks so examples inside them are not checked.
String prose(String markdown) {
  final out = StringBuffer();
  String? fence;
  for (final line in markdown.split('\n')) {
    final m = fencePattern.firstMatch(line);
    if (m != null) {
      fence = fence == null ? m[1] : (m[1]![0] == fence[0] ? null : fence);
      continue;
    }
    if (fence == null) out.writeln(line);
  }
  return out.toString();
}

void main() {
  const docsId = LibraryRootId('docs');
  late Library docs;

  setUpAll(() async {
    final registry = LocalFolderRegistry('docs');
    final ref = registry.register('docs', const LocalDirectory('docs'));
    final scanner = LocalFolderScanner(registry);
    final scanned = await scanner.scan(ref);
    final loaded = <FileEntry>[];
    for (final entry in scanned.files) {
      final source = await scanner.scanDocument(ref, entry.path);
      if (source != null) {
        loaded.add(
          FileEntry(entry.path, source.content, sourceId: source.sourceId),
        );
      }
    }
    docs = Library(
      roots: [
        LibraryBuilder.buildRoot(id: docsId, name: scanned.name, files: loaded),
      ],
    );
  });

  test('docs open as a library with nested shelves', () {
    expect(docs.isEmpty, isFalse);
    expect(
      docs.roots.single.folder.folders.map((f) => f.name),
      contains('00-foundation'),
    );
    expect(docs.openingDocument?.id.path, 'README.md');
  });

  test('every shelf has a README', () {
    final missing = <String>[];
    void visit(Folder folder) {
      if (!folder.documents.any((d) => d.isReadme)) missing.add(folder.path);
      folder.folders.forEach(visit);
    }

    visit(docs.roots.single.folder);
    expect(missing, isEmpty, reason: 'folders without a README');
  });

  test('every document declares a title', () {
    final untitled = docs.documents
        .where((d) => d.outline.title == null)
        .map((d) => d.id.path);
    expect(untitled, isEmpty);
  });

  test('no placeholders were left behind', () {
    final dirty = docs.documents
        .where(
          (d) => RegExp(
            r'\bTODO\b|\bTBD\b|lorem ipsum',
            caseSensitive: false,
          ).hasMatch(d.content),
        )
        .map((d) => d.id.path);
    expect(dirty, isEmpty);
  });

  test('every relative link resolves to a document and an existing anchor', () {
    final broken = <String>[];
    for (final Document doc in docs.documents) {
      for (final match in linkPattern.allMatches(prose(doc.content))) {
        final href = match[1]!;
        if (Uri.tryParse(href)?.hasScheme ?? false) continue;
        final hash = href.indexOf('#');
        final path = hash < 0 ? href : href.substring(0, hash);
        final anchor = hash < 0 ? null : href.substring(hash + 1);
        final target = path.isEmpty ? doc : docs.find(doc.id.resolve(path));
        if (target == null) {
          broken.add('${doc.id}: $href (no document)');
        } else if (anchor != null &&
            target.outline.tableOfContents.byAnchor(anchor) == null) {
          broken.add('${doc.id}: $href (no anchor)');
        }
      }
    }
    expect(broken, isEmpty, reason: 'broken links');
  });

  test('every source reference points at a file that exists', () {
    final missing = <String>[];
    for (final doc in docs.documents) {
      for (final match in sourceReferencePattern.allMatches(doc.content)) {
        final path = match[1]!;
        if (!File(path).existsSync()) missing.add('${doc.id}: $path');
      }
    }
    expect(missing, isEmpty, reason: 'missing source files');
  });

  test('exact line citations never couple prose to source layout', () {
    final coupled = <String>[];
    for (final doc in docs.documents) {
      for (final match in lineCitationPattern.allMatches(doc.content)) {
        coupled.add('${doc.id}: ${match[0]}');
      }
    }
    expect(coupled, isEmpty, reason: 'exact line citations');
  });

  test('source references exist — the inventory is evidence-based', () {
    final componentDocs = docs.documents.where(
      (d) =>
          !d.isReadme &&
          !d.id.path.startsWith('07-decisions') &&
          !d.id.path.startsWith('00-foundation'),
    );
    final uncited = componentDocs
        .where((d) => !sourceReferencePattern.hasMatch(d.content))
        .map((d) => d.id.path);
    expect(
      uncited,
      isEmpty,
      reason: 'component documents without source evidence',
    );
  });

  test('DocumentId.resolve is exercised by real cross-shelf links', () {
    final crossShelf = docs.documents
        .expand(
          (d) => linkPattern.allMatches(prose(d.content)).map((m) => m[1]!),
        )
        .where((href) => href.startsWith('../'));
    expect(crossShelf, isNotEmpty);
    expect(
      DocumentId(
        docsId,
        '03-infrastructure/web/01-folder-drop.md',
      ).resolve('../../01-domain/README.md').path,
      '01-domain/README.md',
    );
  });
}
