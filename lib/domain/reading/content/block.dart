import 'inline.dart';

/// The block-level content of a document: the shapes a page is built from.
sealed class Block {
  const Block();

  /// Every word in this block, without decoration.
  String get text;
}

/// Compact visible-text facts carried beside a revisioned block.
///
/// Rendering offsets and geometry estimates need length and authored-line
/// count, not a newly flattened copy of every inline run. Keeping those facts
/// in the reading model lets an append extend them from its suffix while the
/// original semantic tree remains intact.
final class BlockTextMetrics {
  final int codeUnits;
  final int lineBreaks;

  const BlockTextMetrics({required this.codeUnits, required this.lineBreaks})
    : assert(codeUnits >= 0),
      assert(lineBreaks >= 0),
      assert(lineBreaks <= codeUnits);

  factory BlockTextMetrics.fromText(String text) =>
      BlockTextMetrics(codeUnits: text.length, lineBreaks: _lineBreaksIn(text));

  factory BlockTextMetrics.fromInlines(Iterable<Inline> content) {
    var codeUnits = 0;
    var lineBreaks = 0;

    void addText(String text) {
      codeUnits += text.length;
      lineBreaks += _lineBreaksIn(text);
    }

    void visit(Inline inline) {
      switch (inline) {
        case TextRun(:final text) ||
            CodeRun(:final text) ||
            MathRun(source: final text) ||
            FootnoteReferenceRun(:final text) ||
            FootnoteBackReferenceRun(:final text) ||
            ImageRun(:final text):
          addText(text);
        case LineBreakRun():
          codeUnits++;
          lineBreaks++;
        case MarkedRun(:final children) || LinkRun(:final children):
          for (final child in children) {
            visit(child);
          }
      }
    }

    for (final inline in content) {
      visit(inline);
    }
    return BlockTextMetrics(codeUnits: codeUnits, lineBreaks: lineBreaks);
  }

  factory BlockTextMetrics.fromBlock(Block block) => _metricsForBlock(block);

  BlockTextMetrics append(BlockTextMetrics suffix) => BlockTextMetrics(
    codeUnits: codeUnits + suffix.codeUnits,
    lineBreaks: lineBreaks + suffix.lineBreaks,
  );
}

/// Joins visible block text without letting navigation-only blocks invent a
/// separator. Containers and the top-level document use the same rule so
/// search offsets remain identical to the page at every nesting depth.
String readingTextOfBlocks(Iterable<Block> blocks, String separator) => blocks
    .where((block) => block is! AnchorBlock)
    .map((block) => block.text)
    .join(separator);

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

/// A zero-height navigation target between two document blocks.
final class AnchorBlock extends Block {
  final String name;

  const AnchorBlock(this.name);

  @override
  String get text => '';
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
  String get text => readingTextOfBlocks(blocks, '\n');
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

  String get text => readingTextOfBlocks(blocks, '\n');
}

/// The definitions collected at the end of a document by the Markdown
/// grammar, in first-reference order.
final class FootnoteSectionBlock extends Block {
  final List<FootnoteDefinition> definitions;

  const FootnoteSectionBlock(this.definitions);

  @override
  String get text =>
      definitions.map((definition) => definition.text).join('\n');
}

final class FootnoteDefinition {
  final int number;
  final String anchor;

  /// Whether this definition is the first claimant of [anchor].
  final bool ownsAnchor;
  final List<Block> blocks;

  const FootnoteDefinition({
    required this.number,
    required this.anchor,
    this.ownsAnchor = true,
    required this.blocks,
  });

  String get text => readingTextOfBlocks(blocks, '\n');
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

BlockTextMetrics _metricsForBlock(Block block) => switch (block) {
  ParagraphBlock(:final content) ||
  HeadingBlock(:final content) => BlockTextMetrics.fromInlines(content),
  AnchorBlock() ||
  RuleBlock() => const BlockTextMetrics(codeUnits: 0, lineBreaks: 0),
  CodeBlock(:final code) => BlockTextMetrics.fromText(code),
  MathBlock(:final source) ||
  MermaidBlock(:final source) => BlockTextMetrics.fromText(source),
  QuoteBlock(:final blocks) => _metricsSeparated(
    blocks.where((child) => child is! AnchorBlock).map(_metricsForBlock),
    separator: '\n',
  ),
  ListBlock(:final items) => _metricsSeparated(
    items.map(
      (item) => _metricsSeparated(
        item.blocks
            .where((child) => child is! AnchorBlock)
            .map(_metricsForBlock),
        separator: '\n',
      ),
    ),
    separator: '\n',
  ),
  FootnoteSectionBlock(:final definitions) => _metricsSeparated(
    definitions.map(
      (definition) => _metricsSeparated(
        definition.blocks
            .where((child) => child is! AnchorBlock)
            .map(_metricsForBlock),
        separator: '\n',
      ),
    ),
    separator: '\n',
  ),
  TableBlock(:final head, :final rows) => _metricsSeparated(
    [head, ...rows].map(
      (row) => _metricsSeparated(
        row.map((cell) => BlockTextMetrics.fromInlines(cell.content)),
        separator: '\t',
      ),
    ),
    separator: '\n',
  ),
  RawBlock(:final text) => BlockTextMetrics.fromText(text),
};

BlockTextMetrics _metricsSeparated(
  Iterable<BlockTextMetrics> values, {
  required String separator,
}) {
  final separatorMetrics = BlockTextMetrics.fromText(separator);
  var result = const BlockTextMetrics(codeUnits: 0, lineBreaks: 0);
  var first = true;
  for (final value in values) {
    if (!first) result = result.append(separatorMetrics);
    result = result.append(value);
    first = false;
  }
  return result;
}

int _lineBreaksIn(String text) {
  var count = 0;
  for (var index = 0; index < text.length; index++) {
    if (text.codeUnitAt(index) == 10) count++;
  }
  return count;
}
