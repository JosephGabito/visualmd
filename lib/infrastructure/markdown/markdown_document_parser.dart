import 'package:markdown/markdown.dart' as md;

import '../../application/ports/document_parser.dart';
import '../../domain/reading/content/block.dart';
import '../../domain/reading/content/document_content.dart';
import '../../domain/reading/content/inline.dart';
import '../../domain/reading/heading_anchor.dart';

/// Adapter: turns markdown source into the domain's blocks.
///
/// The specification is large and full of corners, so the parsing itself is
/// borrowed from `package:markdown`; this class only maps that package's HTML
/// shaped tree onto the model the reader is written against. Nothing here
/// decides how anything looks: the author's text is carried across exactly as
/// written, and how it is *set* — which quote marks, which figures — is
/// settled later, in presentation.
final class MarkdownDocumentParser implements DocumentParser {
  const MarkdownDocumentParser();

  @override
  DocumentContent parse(String markdown) {
    final nodes = md.Document(
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
    final runs = <Inline>[];
    for (final node in nodes ?? const <md.Node>[]) {
      switch (node) {
        case md.Text():
          // A single newline inside a paragraph is a space. Treating it as a
          // break would impose the source file's wrapping on the page.
          runs.add(TextRun(node.text.replaceAll('\n', ' ')));

        case md.Element(tag: 'code'):
          runs.add(CodeRun(node.textContent));

        case md.Element(tag: 'em'):
          runs.add(MarkedRun(InlineMark.emphasis, inlines(node.children)));

        case md.Element(tag: 'strong'):
          runs.add(MarkedRun(InlineMark.strong, inlines(node.children)));

        case md.Element(tag: 'del'):
          runs.add(MarkedRun(InlineMark.strikethrough, inlines(node.children)));

        case md.Element(tag: 'a'):
          runs.add(
            LinkRun(
              href: node.attributes['href'] ?? '',
              title: node.attributes['title'],
              children: inlines(node.children),
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
            runs.addAll(inlines(children));
          } else if (node.textContent.isNotEmpty) {
            runs.add(TextRun(node.textContent));
          }

        default:
          continue;
      }
    }
    return runs;
  }
}
