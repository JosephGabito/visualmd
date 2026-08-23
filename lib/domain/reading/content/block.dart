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

  const TableCell(this.content, {this.alignment = ColumnAlignment.start});

  String get text => content.map((c) => c.text).join();
}

enum ColumnAlignment { start, center, end }

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
