import 'inline.dart';

/// The block-level content of a document: the shapes a page is built from.
sealed class Block {
  const Block();

  /// Every word in this block, without decoration.
  String get text;
}

final class ParagraphBlock extends Block {
  final List<Inline> content;

  const ParagraphBlock(this.content);

  @override
  String get text => content.map((c) => c.text).join();
}

final class HeadingBlock extends Block {
  /// 1 (h1) … 6 (h6).
  final int level;
  final List<Inline> content;

  /// The slug this heading is reachable by, unique within the document.
  final String anchor;

  const HeadingBlock({
    required this.level,
    required this.content,
    required this.anchor,
  });

  @override
  String get text => content.map((c) => c.text).join();
}

/// Verbatim source, with the language the author named, if any.
final class CodeBlock extends Block {
  final String code;
  final String? language;

  const CodeBlock({required this.code, this.language});

  @override
  String get text => code;
}

/// A display equation, kept as authored TeX until the page typesets it.
///
/// TeX is a document language of its own. The domain preserves the source
/// rather than reducing it to glyphs or binding it to a rendering package, so
/// search, copying, persistence, and a failed renderer all retain the equation
/// the author wrote.
final class MathBlock extends Block {
  final String source;

  const MathBlock(this.source);

  @override
  String get text => source;
}

/// A diagram definition kept as authored Mermaid source.
///
/// The domain knows that this block is a diagram rather than ordinary source,
/// but it does not know which engine will validate, lay out, or draw it. That
/// keeps search, copying, persistence, and failure recovery lossless.
final class MermaidBlock extends Block {
  final String source;

  const MermaidBlock(this.source);

  @override
  String get text => source;
}

final class QuoteBlock extends Block {
  final List<Block> blocks;

  const QuoteBlock(this.blocks);

  @override
  String get text => blocks.map((b) => b.text).join('\n');
}

final class ListBlock extends Block {
  final bool ordered;

  /// The number the author started at; 1 unless they said otherwise.
  final int start;

  /// True when the author left blank lines between items, which is a request
  /// for more air between them.
  final bool loose;

  final List<ListItem> items;

  const ListBlock({
    required this.ordered,
    required this.items,
    this.start = 1,
    this.loose = false,
  });

  @override
  String get text => items.map((i) => i.text).join('\n');
}

final class ListItem {
  final List<Block> blocks;

  /// Set for a task-list item; null when the item is not a task.
  final bool? checked;

  const ListItem(this.blocks, {this.checked});

  String get text => blocks.map((b) => b.text).join('\n');
}

final class TableBlock extends Block {
  final List<TableCell> head;
  final List<List<TableCell>> rows;

  const TableBlock({required this.head, required this.rows});

  @override
  String get text => [
    head.map((c) => c.text).join('\t'),
    for (final row in rows) row.map((c) => c.text).join('\t'),
  ].join('\n');
}

final class TableCell {
  final List<Inline> content;
  final ColumnAlignment alignment;

  const TableCell(this.content, {this.alignment = ColumnAlignment.left});

  String get text => content.map((c) => c.text).join();
}

/// Physical alignment authored by the GFM delimiter row.
///
/// Unlike prose alignment, these values do not follow reading direction:
/// `:---` means left even when a particular cell contains right-to-left text.
enum ColumnAlignment { left, center, right }

final class RuleBlock extends Block {
  const RuleBlock();

  @override
  String get text => '';
}

/// Markup the reader will not render. Kept so nothing is silently lost, and
/// so a document that leans on raw HTML still shows something.
final class RawBlock extends Block {
  @override
  final String text;

  const RawBlock(this.text);
}
