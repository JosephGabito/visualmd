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

/// Selects a file or directory in the desktop's file manager.
Future<void> revealInFileManager(String target) async {
  late final String executable;
  late final List<String> arguments;
  if (Platform.isMacOS) {
    executable = 'open';
    arguments = ['-R', target];
  } else if (Platform.isWindows) {
    executable = 'explorer.exe';
    arguments = ['/select,', target];
  } else {
    final entity = FileSystemEntity.typeSync(target);
    final directory = entity == FileSystemEntityType.directory
        ? target
        : File(target).parent.path;
    executable = 'xdg-open';
    arguments = [directory];
  }
  final result = await Process.run(executable, arguments);
  if (result.exitCode != 0) {
    throw ProcessException(
      executable,
      arguments,
      result.stderr.toString().trim(),
      result.exitCode,
    );
  }
}
