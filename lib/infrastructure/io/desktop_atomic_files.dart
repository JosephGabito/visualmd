import 'dart:io';

import 'package:flutter/services.dart';

/// Asks the native runner to replace a file as one filesystem operation.
final class DesktopAtomicFiles {
  static const _channel = MethodChannel('com.visualmd.visualmd/atomic-files');

  final bool useNative;

  const DesktopAtomicFiles({this.useNative = true});

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
