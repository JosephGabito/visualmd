import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/application/ports/shelf_source_actions.dart';
import 'package:visualmd/domain/library/document_id.dart';
import 'package:visualmd/domain/library/library_root_id.dart';
import 'package:visualmd/infrastructure/io/desktop_shelf_source_actions.dart';
import 'package:visualmd/infrastructure/io/local_folder.dart';
import 'package:visualmd/infrastructure/io/local_markdown.dart';
import 'package:visualmd/infrastructure/io/scoped_access.dart';

void main() {
  test(
    'desktop shelf locations resolve without leaking paths into domain ids',
    () {
      String beneath(String root, String relative) =>
          File([root, ...relative.split('/')].join(Platform.pathSeparator))
              .absolute
              .path;

      final folders = LocalFolderRegistry('test');
      final markdowns = LocalMarkdownRegistry('test-markdown');
      final root = folders.register(
        'project',
        const LocalDirectory('/work/project'),
        preferredId: 'project-root',
      );
      final standalone = markdowns.register(
        'notes.md',
        const LocalMarkdown('/work/notes.md'),
        preferredId: 'notes-source',
      );
      final actions = DesktopShelfSourceActions(
        folders,
        markdowns,
        access: const OpenAccess(),
      );

      expect(
        actions.absolutePath(
          ShelfFolderLocation(
            rootId: LibraryRootId(root.id),
            relativePath: 'docs',
          ),
        ),
        beneath('/work/project', 'docs'),
      );
      expect(
        actions.absolutePath(
          ShelfDocumentLocation(
            DocumentId(LibraryRootId(root.id), 'docs/guide.md'),
          ),
        ),
        beneath('/work/project', 'docs/guide.md'),
      );
      expect(
        actions.absolutePath(
          ShelfDocumentLocation(
            DocumentId(
              LibraryRootId('standalone-markdown:${standalone.id}'),
              'notes.md',
            ),
          ),
        ),
        File('/work/notes.md').absolute.path,
      );

      for (final unsafe in [
        '../secrets.md',
        'docs/../../secrets.md',
        '/tmp/secrets.md',
        r'C:\secrets.md',
        r'docs\..\secrets.md',
      ]) {
        expect(
          actions.absolutePath(
            ShelfFolderLocation(
              rootId: LibraryRootId(root.id),
              relativePath: unsafe,
            ),
          ),
          isNull,
          reason: unsafe,
        );
      }
    },
  );
}
