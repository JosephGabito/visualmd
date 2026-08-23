import 'heading.dart';

/// A readable chunk of a document: a heading and everything up to the next
/// one. The first section has no heading when the document opens with prose.
final class Section {
  final Heading? heading;

  /// Markdown source of the section, heading line included.
  final String markdown;

  const Section({required this.heading, required this.markdown});
}
