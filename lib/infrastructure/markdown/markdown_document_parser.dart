import 'package:markdown/markdown.dart' as md;

import '../../application/ports/document_parser.dart';
import '../../domain/reading/character_references.dart';
import '../../domain/reading/content/block.dart';
import '../../domain/reading/content/document_content.dart';
import '../../domain/reading/content/inline.dart';
import '../../domain/reading/heading_anchor.dart';

/// Adapter: turns markdown source into the domain's blocks.
///
/// The specification is large and full of corners, so the parsing itself is
/// borrowed from `package:markdown`; this class only maps that package's HTML
/// shaped tree onto the model the reader is written against. Nothing here
/// decides how anything looks: formatting whitespace is resolved into reading
/// text, authorial punctuation remains source, and how it is *set* — which
/// quote marks, which figures — is settled later, in presentation.
final class MarkdownDocumentParser implements DocumentParser {
  const MarkdownDocumentParser();

  @override
  DocumentContent parse(String markdown) {
    final nodes = md.Document(
      // package:markdown currently lets its delimiter resolver consume a
      // shorter pair from a run of three or more tildes. GFM makes the whole
      // run literal, so claim it before the extension syntax sees it.
      inlineSyntaxes: [_LiteralLongTildeRunSyntax()],
      extensionSet: md.ExtensionSet.gitHubFlavored,
      // The reader draws text, not HTML: escaping it here would put `&amp;`
      // on the page.
      encodeHtml: false,
    ).parse(_withoutFrontMatter(markdown));

    return DocumentContent(_Mapper().blocks(nodes));
  }

  /// Front matter belongs to whatever wrote the file, not to the reader, and
  /// is set aside the same way [HeadingAnchors]' neighbour does it in the
  /// outline: a `---` on the first line, up to the next `---` or `...`.
  static String _withoutFrontMatter(String markdown) {
    final source = markdown.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final lines = source.split('\n');
    if (lines.isEmpty || lines.first.trim() != '---') return source;
    for (var i = 1; i < lines.length; i++) {
      final trimmed = lines[i].trim();
      if (trimmed == '---' || trimmed == '...') {
        return lines.sublist(i + 1).join('\n');
      }
    }
    return source;
  }
}

/// Keeps GFM's ineligible long tilde runs out of the delimiter stack.
final class _LiteralLongTildeRunSyntax extends md.InlineSyntax {
  _LiteralLongTildeRunSyntax() : super(r'~{3,}', startCharacter: 0x7e);

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Text(match[0]!));
    return true;
  }
}

/// Walks one document. Held apart from the parser so the anchor counter lives
/// exactly as long as a single parse, and two documents never share numbering.
final class _Mapper {
  final _anchors = HeadingAnchors();

  static const _blockTags = {
    'p',
    'h1',
    'h2',
    'h3',
    'h4',
    'h5',
    'h6',
    'pre',
    'blockquote',
    'ul',
    'ol',
    'table',
    'hr',
    'section',
  };

  List<Block> blocks(List<md.Node>? nodes) {
    final blocks = <Block>[];
    final loose = <md.Node>[];

    void flush() {
      if (loose.isEmpty) return;
      final content = inlines(loose);
      loose.clear();
      if (content.isNotEmpty) blocks.add(ParagraphBlock(content));
    }

    for (final node in nodes ?? const <md.Node>[]) {
      if (node is md.Element && _blockTags.contains(node.tag)) {
        flush();
        blocks.addAll(_block(node));
      } else if (node is md.Text && node.text.trim().isEmpty) {
        // The gaps between blocks; they carry nothing.
        continue;
      } else {
        // A tight list item hands over its content as bare inline nodes.
        loose.add(node);
      }
    }
    flush();
    return blocks;
  }

  /// One element to zero or more blocks. A list, because a `section` — which
  /// is how footnote definitions arrive — is only a wrapper.
  List<Block> _block(md.Element element) {
    switch (element.tag) {
      case 'p':
        final content = inlines(element.children);
        return content.isEmpty ? const [] : [ParagraphBlock(content)];

      case 'h1' || 'h2' || 'h3' || 'h4' || 'h5' || 'h6':
        final content = inlines(element.children);
        final level = int.parse(element.tag.substring(1));
        return [
          HeadingBlock(
            level: level,
            content: content,
            // From the resolved text, so `## The *shelf*` anchors as
            // `the-shelf` rather than carrying its asterisks.
            anchor: _anchors.take(content.map((c) => c.text).join()),
          ),
        ];

      case 'pre':
        return [_code(element)];

      case 'blockquote':
        return [QuoteBlock(blocks(element.children))];

      case 'ul' || 'ol':
        return [_list(element)];

      case 'table':
        return [_table(element)];

      case 'hr':
        return const [RuleBlock()];

      case 'section':
        return blocks(element.children);

      default:
        final text = element.textContent;
        return text.trim().isEmpty ? const [] : [RawBlock(text)];
    }
  }

  CodeBlock _code(md.Element pre) {
    md.Element? code;
    for (final child in pre.children ?? const <md.Node>[]) {
      if (child is md.Element && child.tag == 'code') {
        code = child;
        break;
      }
    }

    var text = (code ?? pre).textContent;
    // The package closes every non-empty block with a newline; that newline is
    // the fence, not a blank last line of the author's code.
    if (text.endsWith('\n')) text = text.substring(0, text.length - 1);

    final className = code?.attributes['class'] ?? '';
    final language = className.startsWith('language-')
        ? className.substring(9)
        : '';
    return CodeBlock(code: text, language: language.isEmpty ? null : language);
  }

  ListBlock _list(md.Element element) {
    final items = <ListItem>[];
    var loose = false;

    for (final item
        in element.children?.whereType<md.Element>() ?? const <md.Element>[]) {
      if (item.tag != 'li') continue;
      final children = item.children ?? const <md.Node>[];

      // A tight list has had its paragraph tags stripped by the package, so a
      // surviving `p` is the author asking for air between items.
      if (children.any((n) => n is md.Element && n.tag == 'p')) loose = true;

      items.add(ListItem(blocks(children), checked: _taskState(item)));
    }

    return ListBlock(
      ordered: element.tag == 'ol',
      items: items,
      start: int.tryParse(element.attributes['start'] ?? '') ?? 1,
      loose: loose,
    );
  }

  /// Whether a list item is a task, and if so whether it is done. The checkbox
  /// arrives as an `input` element, either directly under the item or tucked
  /// inside its first paragraph.
  static bool? _taskState(md.Element item) {
    final checkbox = _findCheckbox(item);
    if (checkbox == null) return null;
    return checkbox.attributes['checked'] == 'true';
  }

  static md.Element? _findCheckbox(md.Node node) {
    if (node is! md.Element) return null;
    if (node.tag == 'input' && node.attributes['type'] == 'checkbox') {
      return node;
    }
    for (final child in node.children ?? const <md.Node>[]) {
      final found = _findCheckbox(child);
      if (found != null) return found;
    }
    return null;
  }

  TableBlock _table(md.Element table) {
    final head = <TableCell>[];
    final rows = <List<TableCell>>[];

    for (final section
        in table.children?.whereType<md.Element>() ?? const <md.Element>[]) {
      for (final row
          in section.children?.whereType<md.Element>() ??
              const <md.Element>[]) {
        if (row.tag != 'tr') continue;
        final cells = [
          for (final cell
              in row.children?.whereType<md.Element>() ?? const <md.Element>[])
            if (cell.tag == 'th' || cell.tag == 'td')
              TableCell(inlines(cell.children), alignment: _alignment(cell)),
        ];
        if (section.tag == 'thead') {
          head.addAll(cells);
        } else {
          rows.add(cells);
        }
      }
    }

    return TableBlock(head: head, rows: rows);
  }

  static ColumnAlignment _alignment(md.Element cell) {
    final align =
        cell.attributes['align'] ?? _alignFromStyle(cell.attributes['style']);
    return switch (align) {
      'center' => ColumnAlignment.center,
      'right' => ColumnAlignment.end,
      _ => ColumnAlignment.start,
    };
  }

  static String? _alignFromStyle(String? style) {
    if (style == null) return null;
    final match = RegExp(r'text-align:\s*(\w+)').firstMatch(style);
    return match?[1];
  }

  List<Inline> inlines(List<md.Node>? nodes) {
    final source = nodes ?? const <md.Node>[];
    return _inlines(source, _InlineLineBreaks(source));
  }

  List<Inline> _inlines(List<md.Node>? nodes, _InlineLineBreaks lineBreaks) {
    final runs = <Inline>[];
    for (final node in nodes ?? const <md.Node>[]) {
      switch (node) {
        case md.Text():
          runs.add(TextRun(lineBreaks.textFor(node)));

        case md.Element(tag: 'code'):
          runs.add(CodeRun(node.textContent));

        case md.Element(tag: 'em'):
          runs.add(
            MarkedRun(InlineMark.emphasis, _inlines(node.children, lineBreaks)),
          );

        case md.Element(tag: 'strong'):
          runs.add(
            MarkedRun(InlineMark.strong, _inlines(node.children, lineBreaks)),
          );

        case md.Element(tag: 'del'):
          runs.add(
            MarkedRun(
              InlineMark.strikethrough,
              _inlines(node.children, lineBreaks),
            ),
          );

        case md.Element(tag: 'a'):
          runs.add(
            LinkRun(
              href: node.attributes['href'] ?? '',
              // package:markdown protects quotes when it stores the parsed
              // title as an HTML-shaped attribute. The domain carries the
              // author's resolved title, not that transport encoding.
              title: switch (node.attributes['title']) {
                final title? => CharacterReferences.decode(title),
                null => null,
              },
              children: _inlines(node.children, lineBreaks),
            ),
          );

        case md.Element(tag: 'img'):
          runs.add(
            ImageRun(
              source: node.attributes['src'] ?? '',
              title: node.attributes['title'],
              alt: node.attributes['alt'] ?? '',
            ),
          );

        case md.Element(tag: 'br'):
          runs.add(const LineBreakRun());

        case md.Element(tag: 'input'):
          // The list item already carries its own tick.
          continue;

        case md.Element():
          // Something we have no shape for — `sup`, inline html, a footnote
          // reference. Its words still belong to the reader, so they are kept
          // even though the markup around them is dropped.
          final children = node.children;
          if (children != null && children.isNotEmpty) {
            runs.addAll(_inlines(children, lineBreaks));
          } else if (node.textContent.isNotEmpty) {
            runs.add(TextRun(node.textContent));
          }

        default:
          continue;
      }
    }
    return _coalesceText(runs);
  }

  /// Parser nodes are grammar boundaries, not reading roles. An escape can
  /// split one prose phrase into several `md.Text` nodes even though every
  /// character belongs to the same typographic context. Joining only adjacent
  /// text runs lets quotes, dashes and ellipses be set across that invisible
  /// boundary without ever crossing code, a mark, a link or an authored line.
  static List<Inline> _coalesceText(List<Inline> runs) {
    final result = <Inline>[];
    for (final run in runs) {
      if (run case TextRun(:final text)) {
        if (text.isEmpty) continue;
        final previous = result.isEmpty ? null : result.last;
        if (previous is TextRun) {
          result[result.length - 1] = TextRun('${previous.text}$text');
          continue;
        }
      }
      result.add(run);
    }
    return result;
  }
}

/// Resolves inline line endings before they enter the domain.
///
/// CommonMark calls an ordinary newline inside inline content a soft break.
/// It is not an authored line: spaces and tabs beside it disappear, and the
/// renderer decides how the two source lines join. Languages that separate
/// words need one space. Chinese and Japanese do not; inserting a Western
/// word space there would make the editor's wrapping visible on the page.
///
/// Two or more spaces or a backslash instead produce a hard break element.
/// That is an authored line, but any indentation at the beginning of the next
/// source line is formatting whitespace and must not become visible reading
/// text.
///
/// The package keeps soft breaks inside `md.Text`, including breaks at the
/// edge of a marked or linked run, while hard breaks are separate elements.
/// This resolver therefore reads the complete inline subtree before changing
/// any one text node. Package-shaped nodes do not escape this adapter.
final class _InlineLineBreaks {
  static const _object = '\u{fffc}';
  static final _aroundBreak = RegExp(r'[ \t]*\n[ \t]*');
  static final _leadingIndent = RegExp(r'^[ \t]+');
  static final _punctuationOrMark = RegExp(
    r'^(?:\p{Punctuation}|\p{Mark})$',
    unicode: true,
  );
  static final _unspacedEastAsian = RegExp(
    r'^(?:\p{Script_Extensions=Han}|'
    r'\p{Script_Extensions=Hiragana}|'
    r'\p{Script_Extensions=Katakana}|'
    r'\p{Script_Extensions=Bopomofo})$',
    unicode: true,
  );

  final Map<md.Text, String> _resolved = Map.identity();

  _InlineLineBreaks(List<md.Node> nodes) {
    final fullText = StringBuffer();
    final pieces = <_InlinePiece>[];
    _collect(nodes, fullText, pieces);
    final context = fullText.toString();
    final scripts = _ScriptContext(context);
    var afterHardBreak = false;

    for (final piece in pieces) {
      switch (piece) {
        case _TextPiece(:final node, :final start):
          var text = node.text.replaceAllMapped(_aroundBreak, (match) {
            final before = scripts.before(start + match.start);
            final after = scripts.after(start + match.end);
            return before != null &&
                    after != null &&
                    _unspacedEastAsian.hasMatch(before) &&
                    _unspacedEastAsian.hasMatch(after)
                ? ''
                : ' ';
          });
          if (afterHardBreak) {
            text = text.replaceFirst(_leadingIndent, '');
          }
          _resolved[node] = text;
          if (text.isNotEmpty) afterHardBreak = false;

        case _HardBreakPiece():
          afterHardBreak = true;

        case _AtomicPiece():
          afterHardBreak = false;
      }
    }
  }

  String textFor(md.Text node) => _resolved[node] ?? node.text;

  static void _collect(
    Iterable<md.Node> nodes,
    StringBuffer fullText,
    List<_InlinePiece> pieces,
  ) {
    for (final node in nodes) {
      switch (node) {
        case md.Text():
          pieces.add(_TextPiece(node, fullText.length));
          fullText.write(node.text);

        case md.Element(tag: 'br'):
          pieces.add(const _HardBreakPiece());
          fullText.write(_object);

        case md.Element(tag: 'code' || 'img' || 'input'):
          // An atomic inline is a real boundary. Context on its far side must
          // not decide how a nearby soft break joins.
          pieces.add(const _AtomicPiece());
          fullText.write(_object);

        case md.Element(:final children):
          _collect(children ?? const <md.Node>[], fullText, pieces);

        default:
          continue;
      }
    }
  }

  static bool _ignorableForScript(String character) =>
      character == ' ' ||
      character == '\t' ||
      character == '\n' ||
      _punctuationOrMark.hasMatch(character);
}

sealed class _InlinePiece {
  const _InlinePiece();
}

final class _TextPiece extends _InlinePiece {
  final md.Text node;
  final int start;

  const _TextPiece(this.node, this.start);
}

final class _HardBreakPiece extends _InlinePiece {
  const _HardBreakPiece();
}

final class _AtomicPiece extends _InlinePiece {
  const _AtomicPiece();
}

/// Nearest script-bearing characters around every break, indexed once.
///
/// Looking outward from every newline independently would become quadratic in
/// a punctuation-heavy paragraph. One linear pass plus binary searches keeps
/// source-wrap normalisation responsive even for hostile input.
final class _ScriptContext {
  final List<_ScriptCharacter> _characters = [];

  _ScriptContext(String text) {
    var offset = 0;
    while (offset < text.length) {
      final first = text.codeUnitAt(offset);
      final next = offset + 1 < text.length ? text.codeUnitAt(offset + 1) : -1;
      final isSurrogatePair =
          first >= 0xd800 &&
          first <= 0xdbff &&
          next >= 0xdc00 &&
          next <= 0xdfff;
      final end = isSurrogatePair ? offset + 2 : offset + 1;
      final character = text.substring(offset, end);
      if (!_InlineLineBreaks._ignorableForScript(character)) {
        _characters.add(_ScriptCharacter(offset, character));
      }
      offset = end;
    }
  }

  String? before(int end) {
    final insertion = _lowerBound(end);
    return insertion == 0 ? null : _characters[insertion - 1].character;
  }

  String? after(int start) {
    final insertion = _lowerBound(start);
    return insertion == _characters.length
        ? null
        : _characters[insertion].character;
  }

  int _lowerBound(int offset) {
    var low = 0;
    var high = _characters.length;
    while (low < high) {
      final middle = low + ((high - low) >> 1);
      if (_characters[middle].offset < offset) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    return low;
  }
}

final class _ScriptCharacter {
  final int offset;
  final String character;

  const _ScriptCharacter(this.offset, this.character);
}
