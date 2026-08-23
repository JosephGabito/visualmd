import 'block.dart';

/// A document as the reader will meet it: an ordered list of blocks.
final class DocumentContent {
  final List<Block> blocks;

  const DocumentContent(this.blocks);

  static const empty = DocumentContent([]);

  bool get isEmpty => blocks.isEmpty;

  /// Every heading in order, for matching the outline to the page.
  Iterable<HeadingBlock> get headings => blocks.whereType<HeadingBlock>();

  /// Every word in the document, without decoration.
  String get text => blocks.map((b) => b.text).join('\n\n');
}
