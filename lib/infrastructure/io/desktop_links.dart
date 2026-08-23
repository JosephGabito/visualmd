import 'dart:io';

/// Adapter: hands a link to the system's default browser.
Future<void> openWithSystem(String url) async {
  if (Platform.isMacOS) {
    await Process.run('open', [url]);
  } else if (Platform.isWindows) {
    await Process.run('rundll32', ['url.dll,FileProtocolHandler', url]);
  } else {
    await Process.run('xdg-open', [url]);
  }
}
