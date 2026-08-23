import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../../domain/library/document_source_id.dart';

/// Gives equal browser handles one physical identity within the process.
final class BrowserSourceIdentity {
  final _known = <(DocumentSourceId, web.FileSystemFileHandle)>[];
  var _next = 0;

  Future<DocumentSourceId> identify(web.FileSystemFileHandle handle) async {
    for (final (id, known) in _known) {
      if ((await handle.isSameEntry(known).toDart).toDart) return id;
    }
    final id = DocumentSourceId('browser-file-${_next++}');
    _known.add((id, handle));
    return id;
  }
}
