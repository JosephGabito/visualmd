import 'package:flutter/material.dart' hide TableCell;
import 'package:flutter/rendering.dart';

import '../../domain/reading/content/block.dart';
import '../../domain/reading/content/document_content.dart';
import '../../domain/search/search_result.dart';
import '../../presentation/theme/hanging_punctuation.dart';
import '../../presentation/theme/reading_scale.dart';
import '../../presentation/theme/widow_binding.dart';
import '../theme/reading_measure.dart';
import '../widgets/code_block.dart';
import 'inline_composer.dart';
import 'reading_theme.dart';

/// The rules a page of paragraphs is set by.
abstract final class ParagraphRules {
  /// A paragraph is indented only when it follows another paragraph.
  ///
  /// An indent signals a separation from the text above. The paragraph that
  /// opens a document or a section has nothing behind it to be separated
  /// from, and one resuming after a list, a quotation or a code block is
  /// already separated by the space that block leaves — indenting it too
  /// would be the same signal said twice.
  static bool indents(Block? previous, ParagraphMarking marking) =>
      marking == ParagraphMarking.indented && previous is ParagraphBlock;
}

/// Sets a document on the page.
///
/// The page is built block by block rather than handed to a general-purpose
/// renderer, because the two things a reader needs most cannot be expressed
/// in a style sheet:
///
/// * **Prose and code want different columns.** Prose is bound by the
///   measure — around 66 characters. Code is written in lines of its own
///   length and may not be re-wrapped, so it is given more room and scrolls
///   when it still does not fit.
/// * **The vertical rhythm is a rule, not a series of paddings.** Every gap
///   is cut from one line of body text and emitted after the block that owns
///   it. Nothing adds external space above itself.
/// * **Paragraphs are marked by one signal, not two.** See [ParagraphRules].
class DocumentView extends StatelessWidget {
  final DocumentContent content;
  final ReadingTheme theme;

  /// Keys by heading anchor, so the outline can bring a heading into view.
  final Map<String, GlobalKey> anchorKeys;

  final void Function(String href)? onTapLink;
  final List<TextMatch> matches;
  final int activeMatch;
  final Map<int, GlobalKey> matchKeys;

  DocumentView({
    super.key,
    required this.content,
    required this.theme,
    required this.anchorKeys,
    this.onTapLink,
    this.matches = const [],
    this.activeMatch = -1,
    Map<int, GlobalKey>? matchKeys,
  }) : matchKeys = matchKeys ?? <int, GlobalKey>{};

  @override
  Widget build(BuildContext context) {
    final composer = InlineComposer(
      theme: theme,
      onTapLink: onTapLink,
      matches: matches,
      activeMatch: activeMatch,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        final prose = theme.proseWidth(available);
        final wide = theme.wideWidth(available);

        return _BlockSequence(
          blocks: content.blocks,
          theme: theme,
          composer: composer,
          keys: anchorKeys,
          matchKeys: matchKeys,
          // A fixed width, not a maximum: a code block's ground should span
          // its column rather than shrinking to the length of its shortest
          // line, and prose should wrap at the measure rather than at the
          // width of the paragraph that happens to be longest.
          widthFor: (block) => _widthFor(block, prose, wide),
        );
      },
    );
  }

  static double _widthFor(Block block, double prose, double wide) =>
      switch (block) {
        CodeBlock() || TableBlock() => wide,
        _ => prose,
      };
}

/// Sets a run of blocks from top to bottom.
///
/// Every external gap is emitted after the block that owns it. The same rule
/// applies at every depth, so a quotation or list item cannot introduce a
/// second spacing convention of its own.
class _BlockSequence extends StatelessWidget {
  final List<Block> blocks;
  final ReadingTheme theme;
  final InlineComposer composer;
  final Map<String, GlobalKey> keys;
  final Map<int, GlobalKey> matchKeys;
  final double Function(Block block)? widthFor;
  final int startOffset;
  final int separatorLength;

  const _BlockSequence({
    required this.blocks,
    required this.theme,
    required this.composer,
    required this.keys,
    required this.matchKeys,
    this.widthFor,
    this.startOffset = 0,
    this.separatorLength = 2,
  });

  @override
  Widget build(BuildContext context) {
    final marking = theme.scale.marking;
    final children = <Widget>[];
    var offset = startOffset;
    for (var i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      final previous = i == 0 ? null : blocks[i - 1];
      final next = i + 1 < blocks.length ? blocks[i + 1] : null;
      final followingSpace = theme.spaceAfter(block, next);

      final view = _BlockView(
        block: block,
        theme: theme,
        composer: composer,
        keys: keys,
        matchKeys: matchKeys,
        offset: offset,
        indent: ParagraphRules.indents(previous, marking) ? theme.indent : 0,
        followingSpace: followingSpace,
      );
      final width = widthFor?.call(block);
      children.add(
        width == null
            ? view
            : Align(
                alignment: Alignment.topCenter,
                child: SizedBox(width: width, child: view),
              ),
      );
      if (followingSpace > 0) {
        children.add(SizedBox(height: followingSpace));
      }
      offset += block.text.length + separatorLength;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

class _BlockView extends StatelessWidget {
  final Block block;
  final ReadingTheme theme;
  final InlineComposer composer;
  final Map<String, GlobalKey> keys;
  final Map<int, GlobalKey> matchKeys;
  final int offset;
  final double followingSpace;

  /// The first-line indent this paragraph is set with; 0 for every other kind
  /// of block, and for a paragraph that opens a document or a section.
  final double indent;

  const _BlockView({
    required this.block,
    required this.theme,
    required this.composer,
    required this.keys,
    required this.matchKeys,
    required this.offset,
    required this.followingSpace,
    this.indent = 0,
  });

  @override
  Widget build(BuildContext context) {
    switch (block) {
      case ParagraphBlock(:final content):
        // The style comes from the theme in hand, which inside a quotation is
        // the quoting one.
        return _matchTarget(
          Paragraph(
            spans: composer.compose(content, style: theme.body, offset: offset),
            style: theme.body,
            textScaler: theme.textScaler,
            strut: theme.strutFor(theme.body),
            indent: indent,
          ),
        );

      case HeadingBlock(:final level, :final content, :final anchor):
        return _matchTarget(
          KeyedSubtree(
            key: keys.putIfAbsent(anchor, GlobalKey.new),
            child: _RhythmicHeading(
              beat: theme.baseline,
              followingSpace: followingSpace,
              child: Text.rich(
                TextSpan(
                  children: composer.compose(
                    content,
                    style: theme.heading(level),
                    offset: offset,
                  ),
                ),
              ),
            ),
          ),
        );

      case CodeBlock(:final code):
        return _matchTarget(
          ReadableCodeBlock(
            source: code,
            spans: composer.verbatim(code, style: theme.code, offset: offset),
            textStyle: theme.code,
            // Half a beat above and below: with each line of code set to one
            // beat, the whole block comes to a whole number of them and the
            // prose beneath it resumes on the grid.
            padding: EdgeInsets.symmetric(
              horizontal: theme.renderedBase * 0.9,
              vertical: theme.baseline / 2,
            ),
            // Its own ground is enough to say what it is; a border as well
            // would be the same signal twice, and a border has a height.
            decoration: BoxDecoration(
              color: theme.palette.codeBackground,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );

      case QuoteBlock(:final blocks):
        return _Quote(
          blocks: blocks,
          theme: theme,
          composer: composer,
          keys: keys,
          matchKeys: matchKeys,
          offset: offset,
        );

      case ListBlock():
        return _List(
          list: block as ListBlock,
          theme: theme,
          composer: composer,
          keys: keys,
          matchKeys: matchKeys,
          offset: offset,
        );

      case TableBlock():
        return _matchTarget(
          _Table(
            table: block as TableBlock,
            theme: theme,
            composer: composer,
            offset: offset,
          ),
        );

      case RuleBlock():
        return SizedBox(
          height: theme.baseline,
          child: Center(
            child: Divider(
              height: 1,
              thickness: 1,
              color: theme.palette.border,
            ),
          ),
        );

      case RawBlock(:final text):
        return _matchTarget(
          Text.rich(
            TextSpan(
              children: composer.verbatim(
                text,
                style: theme.body.copyWith(color: theme.palette.muted),
                offset: offset,
              ),
            ),
          ),
        );
    }
  }

  Widget _matchTarget(Widget child) {
    final indexes = [
      for (var i = 0; i < composer.matches.length; i++)
        if (composer.matches[i].overlaps(offset, offset + block.text.length)) i,
    ];
    if (indexes.isEmpty) return child;
    final key = GlobalKey();
    for (final index in indexes) {
      matchKeys[index] = key;
    }
    return KeyedSubtree(key: key, child: child);
  }
}

/// Lets display lines use their natural leading, then reconciles the completed
/// heading with the running-text grid.
///
/// [_BlockSequence] owns the external [followingSpace]. This render object
/// accounts for that known outgoing gap and places only the remaining rhythm
/// correction before the heading. It therefore owns no inter-block spacing.
final class _RhythmicHeading extends SingleChildRenderObjectWidget {
  final double beat;
  final double followingSpace;

  const _RhythmicHeading({
    required this.beat,
    required this.followingSpace,
    required super.child,
  });

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderRhythmicHeading(beat, followingSpace);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderRhythmicHeading renderObject,
  ) {
    renderObject
      ..beat = beat
      ..followingSpace = followingSpace;
  }
}

final class _RenderRhythmicHeading extends RenderShiftedBox {
  _RenderRhythmicHeading(this._beat, this._followingSpace, [RenderBox? child])
    : super(child);

  double _beat;
  double get beat => _beat;
  set beat(double value) {
    if (_beat == value) return;
    _beat = value;
    markNeedsLayout();
  }

  double _followingSpace;
  double get followingSpace => _followingSpace;
  set followingSpace(double value) {
    if (_followingSpace == value) return;
    _followingSpace = value;
    markNeedsLayout();
  }

  BoxConstraints _childConstraints(BoxConstraints constraints) =>
      constraints.copyWith(minHeight: 0, maxHeight: double.infinity);

  double _reconciledHeight(double childHeight) =>
      ((childHeight + followingSpace) / beat).ceil() * beat - followingSpace;

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final childSize = child?.getDryLayout(_childConstraints(constraints));
    if (childSize == null) return constraints.smallest;
    return constraints.constrain(
      Size(childSize.width, _reconciledHeight(childSize.height)),
    );
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }

    child.layout(_childConstraints(constraints), parentUsesSize: true);
    size = constraints.constrain(
      Size(child.size.width, _reconciledHeight(child.size.height)),
    );

    final childParentData = child.parentData! as BoxParentData;
    childParentData.offset = Offset(0, size.height - child.size.height);
  }
}

/// A quotation: set in the reader's own voice, marked once by a rule.
class _Quote extends StatelessWidget {
  final List<Block> blocks;
  final ReadingTheme theme;
  final InlineComposer composer;
  final Map<String, GlobalKey> keys;
  final Map<int, GlobalKey> matchKeys;
  final int offset;

  const _Quote({
    required this.blocks,
    required this.theme,
    required this.composer,
    required this.keys,
    required this.matchKeys,
    required this.offset,
  });

  @override
  Widget build(BuildContext context) {
    final quoted = ReadingTheme.quoting(theme);
    return Container(
      padding: EdgeInsets.only(left: theme.em),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: theme.palette.accent.withValues(alpha: 0.5),
            width: 2,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _BlockSequence(
            blocks: blocks,
            theme: quoted,
            composer: composer,
            keys: keys,
            matchKeys: matchKeys,
            startOffset: offset,
            separatorLength: 1,
          ),
        ],
      ),
    );
  }
}

/// A list, with its markers hanging in the margin so the text of every item
/// starts on the same line.
class _List extends StatelessWidget {
  final ListBlock list;
  final ReadingTheme theme;
  final InlineComposer composer;
  final Map<String, GlobalKey> keys;
  final Map<int, GlobalKey> matchKeys;
  final int offset;

  const _List({
    required this.list,
    required this.theme,
    required this.composer,
    required this.keys,
    required this.matchKeys,
    required this.offset,
  });

  @override
  Widget build(BuildContext context) {
    final gutter = theme.em * (list.ordered ? 1.7 : 1.2);
    // A list the author spaced out gets a whole beat between items; a tight
    // one gets none, so its lines follow each other exactly as the lines of a
    // paragraph do.
    final between = list.loose ? theme.blockGap : 0.0;
    final children = <Widget>[];
    var itemOffset = offset;
    for (var i = 0; i < list.items.length; i++) {
      children.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: gutter,
              child: _Marker(list: list, index: i, theme: theme),
            ),
            Expanded(
              child: _BlockSequence(
                blocks: list.items[i].blocks,
                theme: theme,
                composer: composer,
                keys: keys,
                matchKeys: matchKeys,
                startOffset: itemOffset,
                separatorLength: 1,
              ),
            ),
          ],
        ),
      );
      if (i + 1 < list.items.length && between > 0) {
        children.add(SizedBox(height: between));
      }
      itemOffset += list.items[i].text.length + 1;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

class _Marker extends StatelessWidget {
  final ListBlock list;
  final int index;
  final ReadingTheme theme;

  const _Marker({required this.list, required this.index, required this.theme});

  @override
  Widget build(BuildContext context) {
    final item = list.items[index];
    if (item.checked != null) {
      return Padding(
        padding: EdgeInsets.only(top: theme.em * 0.25),
        child: Icon(
          item.checked!
              ? Icons.check_box_outlined
              : Icons.check_box_outline_blank,
          size: theme.em,
          color: item.checked! ? theme.palette.accent : theme.palette.muted,
        ),
      );
    }
    // Markers are signposts: they mark the line without competing with it.
    final label = list.ordered ? '${list.start + index}.' : '•';
    return Padding(
      padding: EdgeInsets.only(right: theme.em * 0.5),
      child: Text(label, textAlign: TextAlign.right, style: theme.marker),
    );
  }
}

/// A table: aligned as the author asked, figures lining up in their columns,
/// and scrolling sideways rather than crushing its columns.
class _Table extends StatefulWidget {
  final TableBlock table;
  final ReadingTheme theme;
  final InlineComposer composer;
  final int offset;

  const _Table({
    required this.table,
    required this.theme,
    required this.composer,
    required this.offset,
  });

  @override
  State<_Table> createState() => _TableState();
}

class _TableState extends State<_Table> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cellPadding = EdgeInsets.symmetric(
      horizontal: widget.theme.tableCellHorizontalPadding,
      vertical: widget.theme.em * 0.45,
    );

    Widget cell(TableCell cell, TextStyle style, int offset) => Padding(
      padding: cellPadding,
      child: Text.rich(
        TextSpan(
          children: widget.composer.compose(
            cell.content,
            style: style,
            offset: offset,
          ),
        ),
        textAlign: switch (cell.alignment) {
          ColumnAlignment.start => TextAlign.start,
          ColumnAlignment.center => TextAlign.center,
          ColumnAlignment.end => TextAlign.end,
        },
      ),
    );

    final columns = widget.table.head.length;
    var rowOffset = widget.offset;
    List<Widget> padded(List<TableCell> cells, TextStyle style) {
      var cellOffset = rowOffset;
      final views = <Widget>[];
      for (var i = 0; i < columns; i++) {
        final value = i < cells.length ? cells[i] : const TableCell([]);
        views.add(cell(value, style, cellOffset));
        if (i < cells.length) cellOffset += value.text.length + 1;
      }
      rowOffset += cells.map((cell) => cell.text).join('\t').length + 1;
      return views;
    }

    final head = padded(widget.table.head, widget.theme.tableHead);
    final rows = [
      for (final row in widget.table.rows) padded(row, widget.theme.tableBody),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (columns == 0) return const SizedBox.shrink();

        final minimumWidths = [
          for (var column = 0; column < columns; column++)
            _minimumColumnWidth(column),
        ];
        final minimumTableWidth = minimumWidths.fold<double>(
          0,
          (a, b) => a + b,
        );
        final tableWidth = minimumTableWidth < constraints.maxWidth
            ? constraints.maxWidth
            : minimumTableWidth;
        final expansion = tableWidth / minimumTableWidth;
        final columnWidths = [
          for (final width in minimumWidths) width * expansion,
        ];

        return ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Scrollbar(
            controller: _scroll,
            // A clipped column looks complete. The persistent thumb is the
            // sign that the table continues beyond the reading band.
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: tableWidth,
                child: Table(
                  border: TableBorder.all(color: widget.theme.palette.border),
                  columnWidths: {
                    for (var column = 0; column < columns; column++)
                      column: FixedColumnWidth(columnWidths[column]),
                  },
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: [
                    TableRow(
                      decoration: BoxDecoration(
                        color: widget.theme.palette.panel,
                      ),
                      children: head,
                    ),
                    for (final row in rows) TableRow(children: row),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  double _minimumColumnWidth(int column) {
    var width = widget.theme.minimumTableCellWidth(
      widget.table.head[column].text,
      widget.theme.tableHead,
    );
    for (final row in widget.table.rows) {
      if (column >= row.length) continue;
      final cellWidth = widget.theme.minimumTableCellWidth(
        row[column].text,
        widget.theme.tableBody,
      );
      if (cellWidth > width) width = cellWidth;
    }
    return width;
  }
}

/// One paragraph, set with its indent and with its opening mark hung.
class Paragraph extends StatelessWidget {
  final List<InlineSpan> spans;
  final TextStyle style;
  final TextScaler textScaler;

  /// Holds every line to the same height, so a code span or a smaller run
  /// inside the paragraph cannot push a line off the beat.
  final StrutStyle? strut;

  /// First-line indent. A hanging mark hangs from here, not from the column
  /// edge: the indent moves the line, and the mark hangs off the line.
  final double indent;

  const Paragraph({
    super.key,
    required this.spans,
    required this.style,
    this.textScaler = TextScaler.noScaling,
    this.strut,
    this.indent = 0,
  });

  @override
  Widget build(BuildContext context) {
    final (mark, rest) = splitHangingMark(spans);
    final set = bindWidow(rest);

    final flow = Text.rich(
      strutStyle: strut,
      // Running prose follows the reading direction: flush at the edge where
      // the eye begins each line, ragged at the edge where it leaves. Unlike
      // justification, this never stretches word spaces into rivers.
      textAlign: TextAlign.start,
      softWrap: true,
      TextSpan(
        children: [
          if (indent > 0)
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: SizedBox(width: indent, height: 0),
            ),
          ...set,
        ],
      ),
    );
    if (mark == null) return flow;

    // The mark is taken out of the flow and painted beside it, so the text
    // begins on the column edge and the mark sits outside it. Same style and
    // same top, so the two share the first line's baseline exactly.
    final hang =
        ReadingMeasure.widthOf(mark, style, scaler: textScaler) *
        HangingPunctuation.fractionFor(mark);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        flow,
        Positioned(
          left: indent - hang,
          top: 0,
          child: Text(mark, style: style),
        ),
      ],
    );
  }

  /// Binds the last two words of the paragraph so the final one cannot be
  /// left standing on a line of its own.
  ///
  /// Only the last run is touched, and only when it ends in plain text: a
  /// paragraph ending in code or a link ends with something the reader can
  /// see is deliberate, and its spacing is not ours to change.
  static List<InlineSpan> bindWidow(List<InlineSpan> spans) {
    if (spans.isEmpty) return spans;
    final words = spans
        .map(_plainOf)
        .join()
        .trim()
        .split(RegExp(r'\s+'))
        .length;
    if (words < WidowBinding.leastWords) return spans;

    final last = spans.last;
    final bound = _bindLastLeaf(last);
    if (identical(bound, last)) return spans;
    return [...spans.take(spans.length - 1), bound];
  }

  static String _plainOf(InlineSpan span) =>
      span is TextSpan ? span.toPlainText() : ' ';

  /// Binds the last eligible text leaf while preserving its surrounding mark.
  /// Links and code are deliberate endings: changing their text would change
  /// what gets followed or copied, so they remain untouched.
  static InlineSpan _bindLastLeaf(InlineSpan span) {
    if (span is! TextSpan ||
        span is InlineCodeSpan ||
        span.recognizer != null) {
      return span;
    }
    if (span.style?.backgroundColor != null) return span;

    final children = span.children;
    if (children != null && children.isNotEmpty) {
      final last = children.last;
      final bound = _bindLastLeaf(last);
      if (identical(bound, last)) return span;
      return TextSpan(
        text: span.text,
        children: [...children.take(children.length - 1), bound],
        style: span.style,
        recognizer: span.recognizer,
        mouseCursor: span.mouseCursor,
        onEnter: span.onEnter,
        onExit: span.onExit,
        semanticsLabel: span.semanticsLabel,
        locale: span.locale,
        spellOut: span.spellOut,
      );
    }

    final text = span.text;
    if (text == null || text.isEmpty) return span;
    final bound = WidowBinding.bindLastSpace(text);
    if (bound == text) return span;
    return TextSpan(
      text: bound,
      style: span.style,
      recognizer: span.recognizer,
      mouseCursor: span.mouseCursor,
      onEnter: span.onEnter,
      onExit: span.onExit,
      semanticsLabel: span.semanticsLabel,
      locale: span.locale,
      spellOut: span.spellOut,
    );
  }

  /// Splits an opening mark off the front of a paragraph, when it has one.
  ///
  /// Only a paragraph that *begins* with plain text can hang: a line opening
  /// with a link or with emphasis carries more than punctuation, and pulling
  /// that into the margin would move meaning rather than ink.
  static (String?, List<InlineSpan>) splitHangingMark(List<InlineSpan> spans) {
    if (spans.isEmpty) return (null, spans);
    final first = spans.first;
    if (first is! TextSpan) return (null, spans);
    final text = first.text;
    if (text == null || text.isEmpty) return (null, spans);
    final mark = text[0];
    if (!HangingPunctuation.hangs(mark)) return (null, spans);
    return (
      mark,
      [
        TextSpan(
          text: text.substring(1),
          style: first.style,
          children: first.children,
        ),
        ...spans.skip(1),
      ],
    );
  }
}
