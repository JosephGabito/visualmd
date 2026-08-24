import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/application/ports/reader_source_picker.dart';
import 'package:visualmd/infrastructure/io/desktop_reader_source_picker.dart';
import 'package:visualmd/infrastructure/io/local_folder.dart';
import 'package:visualmd/infrastructure/io/local_markdown.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the native Open panel returns typed opaque reader sources', () async {
    const channel = MethodChannel('com.visualmd.visualmd/reader-source-picker');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'pick');
          return [
            {'kind': 'folder', 'path': '/Users/reader/Notes'},
            {'kind': 'markdown', 'path': '/Users/reader/plan.md'},
            {'kind': 'markdown', 'path': '/Users/reader/image.png'},
          ];
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    final folders = LocalFolderRegistry('folder');
    final markdowns = LocalMarkdownRegistry('markdown');
    final picker = DesktopReaderSourcePicker(folders, markdowns);

    final selected = await picker.pick();

    expect(selected, hasLength(2));
    final folder = (selected.first as FolderSourceSelection).ref;
    final markdown = (selected.last as MarkdownSourceSelection).ref;
    expect(folder.name, 'Notes');
    expect(folders.lookup(folder), isA<LocalDirectory>());
    expect(
      (folders.lookup(folder)! as LocalDirectory).path,
      '/Users/reader/Notes',
    );
    expect(markdown.name, 'plan.md');
    expect(markdowns.lookup(markdown)?.path, '/Users/reader/plan.md');
  });

  test('cancelling Open returns no reader sources', () async {
    const channel = MethodChannel('com.visualmd.visualmd/reader-source-picker');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => <Object?>[]);
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    final selected = await DesktopReaderSourcePicker(
      LocalFolderRegistry('folder'),
      LocalMarkdownRegistry('markdown'),
    ).pick();

    expect(selected, isEmpty);
  });
}
