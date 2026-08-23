/// A theme document the reader could not use, with a reason its author can act on.
final class ThemeFormatException implements Exception {
  final String reason;
  const ThemeFormatException(this.reason);

  @override
  String toString() => 'ThemeFormatException: $reason';
}
