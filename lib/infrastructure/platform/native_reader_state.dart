/// The small reader projection needed by native window chrome.
///
/// Hosts use capability booleans rather than inferring state from a title or
/// document count. That keeps native menu validation faithful to the same
/// controller state the Flutter chrome presents.
final class NativeReaderState {
  final String? documentTitle;
  final bool hasLibrary;
  final bool hasDocument;
  final bool hasOutline;
  final bool canCopy;
  final bool canIncreaseText;
  final bool canDecreaseText;
  final bool canResetText;
  final bool shelfVisible;
  final bool outlineVisible;

  const NativeReaderState({
    required this.documentTitle,
    required this.hasLibrary,
    required this.hasDocument,
    required this.hasOutline,
    required this.canCopy,
    required this.canIncreaseText,
    required this.canDecreaseText,
    required this.canResetText,
    required this.shelfVisible,
    required this.outlineVisible,
  });
}
