import '../application/ports/reader_source_picker.dart';
import 'reader_controller.dart';

/// Opens a platform selection through the same add paths used by drops and
/// the explicit File-menu actions.
final class ReaderSourceOpener {
  final ReaderSourcePicker _picker;
  final ReaderController _controller;
  var _picking = false;

  ReaderSourceOpener(this._picker, this._controller);

  Future<void> call() async {
    if (_picking || _controller.opening) return;
    _picking = true;
    try {
      await open(await _picker.pick());
    } on Object catch (failure) {
      _controller.reportReaderSourcePickerFailure(failure);
    } finally {
      _picking = false;
    }
  }

  /// Opens already-authorised selections, such as files delivered by Finder.
  Future<void> open(Iterable<ReaderSourceSelection> sources) async {
    for (final source in sources) {
      switch (source) {
        case FolderSourceSelection(:final ref):
          await _controller.addFolder(ref);
        case MarkdownSourceSelection(:final ref):
          await _controller.addMarkdown(ref);
      }
    }
  }
}
