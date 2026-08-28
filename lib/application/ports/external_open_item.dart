import 'reader_source_picker.dart';
import 'workspace_files.dart';

/// One document the operating system asked the running reader to open.
///
/// Platform paths and permission tokens have already been hidden behind the
/// same opaque references used by explicit Open panels before this value
/// crosses into the application-facing contract.
sealed class ExternalOpenItem {
  const ExternalOpenItem();
}

final class ExternalReaderSource extends ExternalOpenItem {
  final ReaderSourceSelection source;

  const ExternalReaderSource(this.source);
}

final class ExternalWorkspace extends ExternalOpenItem {
  final WorkspaceFileRef file;

  const ExternalWorkspace(this.file);
}
