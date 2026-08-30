/// Transient reader surfaces that can be requested by the native host.
///
/// The composition root translates platform commands into these UI-owned
/// intents so the API ring never imports an infrastructure type.
enum ReaderUiCommand {
  openAppearance,
  findDocument,
  searchLibrary,
  toggleShelf,
  toggleOutline,
  copySelection,
  selectAllText,
  showKeyboardShortcuts,
  showLicenses,
}
