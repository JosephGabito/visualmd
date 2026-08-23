import 'heading.dart';

final class TableOfContents {
  final List<Heading> headings;

  const TableOfContents(this.headings);

  bool get isEmpty => headings.isEmpty;
  bool get isNotEmpty => headings.isNotEmpty;

  /// Shallowest level present, so the panel can indent relative to it.
  int get baseLevel => headings.isEmpty
      ? 1
      : headings.map((h) => h.level).reduce((a, b) => a < b ? a : b);

  Heading? byAnchor(String anchor) {
    for (final heading in headings) {
      if (heading.anchor == anchor) return heading;
    }
    return null;
  }
}
