import 'dart:io';

import 'package:flutter/services.dart';

/// Keeps atomic filesystem details in the desktop adapter that owns them.
final class DesktopAtomicFiles {
  static const _channel = MethodChannel('com.visualmd.visualmd/atomic-files');

  final bool useNative;

  const DesktopAtomicFiles({this.useNative = true});

  /// Writes a user-selected file without inventing paths outside its grant.
  Future<void> writeSelected({
    required File target,
    required String contents,
  }) async {
    if (useNative && Platform.isMacOS) {
      try {
        await _channel.invokeMethod<void>('writeSelected', {
          'target': target.path,
          'contents': contents,
        });
        return;
      } on MissingPluginException {
        // Tests and unsupported desktop embedders use the recoverable fallback.
      }
    }

    final temporary = File('${target.path}.writing');
    final backup = File('${target.path}.bak');
    await temporary.writeAsString(contents, flush: true);
    await replace(target: target, temporary: temporary, backup: backup);
  }

  Future<void> replace({
    required File target,
    required File temporary,
    required File backup,
  }) async {
    if (useNative && (Platform.isMacOS || Platform.isWindows)) {
      try {
        await _channel.invokeMethod<void>('replace', {
          'target': target.path,
          'temporary': temporary.path,
          'backup': backup.path,
        });
        return;
      } on MissingPluginException {
        // Tests and unsupported desktop embedders have no native runner.
      }
    }
    await _recoverableReplace(
      target: target,
      temporary: temporary,
      backup: backup,
    );
  }
}

Future<void> _recoverableReplace({
  required File target,
  required File temporary,
  required File backup,
}) async {
  if (!await target.exists()) {
    await temporary.rename(target.path);
    return;
  }
  if (await backup.exists()) await backup.delete();
  await target.rename(backup.path);
  try {
    await temporary.rename(target.path);
  } on Object {
    if (!await target.exists() && await backup.exists()) {
      await backup.rename(target.path);
    }
    rethrow;
  }
}
