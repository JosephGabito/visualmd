import 'dart:io';

import 'package:flutter/services.dart';

/// Creates a durable read-only security bookmark for a user-selected path.
abstract final class DesktopBookmarks {
  static const _channel = MethodChannel('com.visualmd.visualmd/bookmarks');

  static Future<Uint8List?> create(String path) async {
    if (!Platform.isMacOS) return null;
    return _channel.invokeMethod<Uint8List>('create', path);
  }

  static Future<BookmarkResolution?> resolve(Uint8List bookmark) async {
    if (!Platform.isMacOS) return null;
    final value = await _channel.invokeMapMethod<String, Object?>(
      'resolve',
      bookmark,
    );
    if (value == null || value['path'] is! String) return null;
    return BookmarkResolution(
      path: value['path']! as String,
      bookmark: value['bookmark'] is Uint8List
          ? value['bookmark']! as Uint8List
          : bookmark,
      refreshed: value['refreshed'] == true,
    );
  }
}

final class BookmarkResolution {
  final String path;
  final Uint8List bookmark;
  final bool refreshed;

  const BookmarkResolution({
    required this.path,
    required this.bookmark,
    required this.refreshed,
  });
}
