/// Which authored identity a document row uses on the shelf.
enum ShelfLabelMode {
  title,
  fileName;

  static ShelfLabelMode fromStored(String? value) => switch (value) {
    'fileName' => fileName,
    _ => title,
  };

  String get stored => name;
}
