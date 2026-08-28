import 'theme_typefaces.dart';

/// Which proportional voice sets the document.
///
/// A mode selects a role from the active theme rather than naming a font, so
/// the choice survives a palette change and custom themes keep their voice.
enum ReadingMode {
  serif('serif', 'Serif'),
  sans('sans', 'Sans');

  final String stored;
  final String label;

  const ReadingMode(this.stored, this.label);

  String familyOf(ThemeTypefaces typefaces) => switch (this) {
    ReadingMode.serif => typefaces.serif,
    ReadingMode.sans => typefaces.sans,
  };

  static ReadingMode fromStored(String? stored) => switch (stored) {
    'sans' => ReadingMode.sans,
    _ => ReadingMode.serif,
  };
}
