import 'dart:io';
import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';

import 'scoped_access.dart';

/// macOS sandbox: open a security-scoped bookmark around the read, then close it.
final class DesktopSecurityScope implements ScopedAccess {
  const DesktopSecurityScope();

  @override
  Future<T> within<T>(Uint8List? bookmark, Future<T> Function() body) async {
    if (!Platform.isMacOS || bookmark == null || bookmark.isEmpty) {
      return body();
    }
    final drop = DesktopDrop.instance;
    final granted = await drop.startAccessingSecurityScopedResource(
      bookmark: bookmark,
    );
    try {
      return await body();
    } finally {
      if (granted) {
        await drop.stopAccessingSecurityScopedResource(bookmark: bookmark);
      }
    }
  }
}
