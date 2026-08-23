import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../../application/ports/markdown_scanner.dart';
import '../../domain/library/markdown_file.dart';
import 'browser_file_system_access.dart';
import 'browser_markdown.dart';

final class BrowserMarkdownPicker {
  final BrowserMarkdownRegistry _registry;

  const BrowserMarkdownPicker(this._registry);

  Future<MarkdownRef?> pick() async {
    final result = await pickWorkspaceFile();
    if (result.value case final handle?) {
      if (!MarkdownFile.isMarkdown(handle.name)) return null;
      return _registry.register(handle.name, BrowserMarkdownHandle(handle));
    }
    if (result.supported) return null;
    return _pickUpload();
  }

  Future<MarkdownRef?> _pickUpload() {
    final input = web.document.createElement('input') as web.HTMLInputElement
      ..type = 'file'
      ..accept = '.md,.markdown,.mdown,.mkd,text/markdown'
      ..style.display = 'none';
    web.document.body!.append(input);
    final completer = Completer<MarkdownRef?>();
    void finish(MarkdownRef? result) {
      input.remove();
      if (!completer.isCompleted) completer.complete(result);
    }

    input.addEventListener(
      'change',
      ((web.Event _) {
        final file = input.files?.item(0);
        if (file == null || !MarkdownFile.isMarkdown(file.name)) {
          return finish(null);
        }
        finish(_registry.register(file.name, BrowserMarkdownFile(file)));
      }).toJS,
    );
    input.addEventListener('cancel', ((web.Event _) => finish(null)).toJS);
    input.click();
    return completer.future;
  }
}
