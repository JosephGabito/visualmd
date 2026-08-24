import 'dart:io';

/// Adapter: hands a URL or local path to the operating system.
Future<void> openWithSystem(String target) async {
  if (Platform.isMacOS) {
    await Process.run('open', [target]);
  } else if (Platform.isWindows) {
    await Process.run('rundll32', ['url.dll,FileProtocolHandler', target]);
  } else {
    await Process.run('xdg-open', [target]);
  }
}
