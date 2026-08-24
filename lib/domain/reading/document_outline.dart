import 'heading_anchor.dart';
import 'heading.dart';
import 'section.dart';
import 'table_of_contents.dart';

/// The structure a reader navigates by: front matter set aside, a table of
/// contents, and the document cut into sections at each heading.
final class DocumentOutline {
  /// Raw YAML front matter, without the `---` fences. Null when absent.
  final String? frontMatter;
  final TableOfContents tableOfContents;
  final List<Section> sections;

  const DocumentOutline({
    required this.frontMatter,
    required this.tableOfContents,
    required this.sections,
  });

  /// A title the document declares about itself: `title:` in front matter,
  /// else the first h1.
  String? get title {
    final declared = _frontMatterTitle;
    if (declared != null) return declared;
    for (final heading in tableOfContents.headings) {
      if (heading.level == 1) return heading.text;
    }
    return null;
  }

  String? get _frontMatterTitle {
    final fm = frontMatter;
    if (fm == null) return null;
    final match = RegExp(
      r'^title:\s*(.+?)\s*$',
      multiLine: true,
    ).firstMatch(fm);
    if (match == null) return null;
    final value = match[1]!;
    final quoted = RegExp(r'''^(["'])(.*)\1$''').firstMatch(value);
    final title = quoted == null ? value : quoted[2]!;
    return title.isEmpty ? null : title;
  }

  static DocumentOutline parse(String markdown) => _Parser(markdown).parse();
}

final class _Parser {
  final List<String> lines;
  final _anchors = HeadingAnchors();

  _Parser(String markdown)
    : lines = markdown
          .replaceAll('\r\n', '\n')
          .replaceAll('\r', '\n')
          .split('\n');

  static final _fence = RegExp(r'^ {0,3}(`{3,}|~{3,})');
  static final _atx = RegExp(r'^ {0,3}(#{1,6})(?:[ \t]+(.*?))?[ \t]*$');
  static final _closingHashes = RegExp(r'^(.*?)[ \t]+#+$');
  static final _setextH1 = RegExp(r'^ {0,3}=+[ \t]*$');
  static final _setextH2 = RegExp(r'^ {0,3}-+[ \t]*$');
  static final _refDefinition = RegExp(r'^ {0,3}\[[^\]]+\]:[ \t]*\S');
  static final _paragraphInterrupt = RegExp(
    r'^ {0,3}(?:#{1,6}(?:[ \t]+|$)|>|[-*+](?:[ \t]+|$)|\d{1,9}[.)](?:[ \t]+|$)|`{3,}|~{3,})',
  );
  static final _thematicBreak = RegExp(
    r'^ {0,3}(?:(?:\*[ \t]*){3,}|(?:-[ \t]*){3,}|(?:_[ \t]*){3,})$',
  );
  static final _tableDelimiter = RegExp(
    r'^ {0,3}\|?(?:[ \t]*:?-+:?[ \t]*\|[ \t]*)+(?:[ \t]|[ \t]*:?-+:?[ \t]*)?$',
  );

  DocumentOutline parse() {
    final (frontMatter, start) = _frontMatter();
    final headings = <Heading>[];
    final refDefinitions = <String>[];
    // (startLine, heading) for each section; first may be heading-less.
    final boundaries = <(int, Heading?)>[(start, null)];

    String? fenceMarker;
    var i = start;
    while (i < lines.length) {
      final line = lines[i];

      final fence = _fence.firstMatch(line);
      if (fence != null) {
        final marker = fence[1]!;
        if (fenceMarker == null) {
          fenceMarker = marker;
        } else if (marker[0] == fenceMarker[0] &&
            marker.length >= fenceMarker.length) {
          fenceMarker = null;
        }
        i++;
        continue;
      }
      if (fenceMarker != null) {
        i++;
        continue;
      }

      if (_refDefinition.hasMatch(line)) refDefinitions.add(line);

      final atx = _atx.firstMatch(line);
      if (atx != null) {
        final heading = _heading(atx[1]!.length, atx[2] ?? '', i);
        headings.add(heading);
        boundaries.add((i, heading));
        i++;
        continue;
      }

      final setext = _setextStartingAt(i);
      if (setext != null) {
        final heading = _heading(setext.level, setext.source, i);
        headings.add(heading);
        boundaries.add((i, heading));
        i = setext.after;
        continue;
      }
      i++;
    }

    return DocumentOutline(
      frontMatter: frontMatter,
      tableOfContents: TableOfContents(List.unmodifiable(headings)),
      sections: List.unmodifiable(_sections(boundaries, refDefinitions)),
    );
  }

  /// A Setext underline promotes the complete paragraph before it, not merely
  /// the last physical line. Stop at the same top-level shapes that can end a
  /// paragraph so the navigation model cannot absorb a list, rule, table or
  /// second heading that the page parser renders separately.
  ({int level, String source, int after})? _setextStartingAt(int start) {
    if (!_canStartParagraph(start)) return null;

    for (var line = start + 1; line < lines.length; line++) {
      final level = _setextH1.hasMatch(lines[line])
          ? 1
          : _setextH2.hasMatch(lines[line])
          ? 2
          : 0;
      if (level > 0) {
        return (
          level: level,
          source: lines.sublist(start, line).join('\n'),
          after: line + 1,
        );
      }
      if (_interruptsParagraph(line)) return null;
    }
    return null;
  }

  bool _canStartParagraph(int line) =>
      lines[line].trim().isNotEmpty &&
      !lines[line].startsWith('    ') &&
      !lines[line].startsWith('\t') &&
      !_refDefinition.hasMatch(lines[line]) &&
      !_interruptsParagraph(line);

  bool _interruptsParagraph(int line) {
    final source = lines[line];
    if (source.trim().isEmpty ||
        _paragraphInterrupt.hasMatch(source) ||
        _thematicBreak.hasMatch(source) ||
        _refDefinition.hasMatch(source) ||
        _tableDelimiter.hasMatch(source)) {
      return true;
    }
    return line + 1 < lines.length && _tableDelimiter.hasMatch(lines[line + 1]);
  }

  /// Returns the front matter body (if any) and the line the document body starts on.
  (String?, int) _frontMatter() {
    if (lines.isEmpty || lines.first.trim() != '---') return (null, 0);
    for (var i = 1; i < lines.length; i++) {
      final t = lines[i].trim();
      if (t == '---' || t == '...') {
        return (lines.sublist(1, i).join('\n'), i + 1);
      }
    }
    return (null, 0);
  }

  Heading _heading(int level, String raw, int line) {
    var text = raw.trim();
    final closing = _closingHashes.firstMatch(text);
    if (closing != null) text = closing[1]!;
    if (RegExp(r'^#+$').hasMatch(text)) text = '';
    text = _plainText(text);
    return Heading(
      level: level,
      text: text,
      anchor: _anchors.take(text),
      line: line,
    );
  }

  static String _plainText(String inline) => inline
      .replaceAllMapped(RegExp(r'!\[([^\]]*)\]\([^)]*\)'), (m) => m[1]!)
      .replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]*\)'), (m) => m[1]!)
      .replaceAllMapped(RegExp(r'\[([^\]]+)\]\[[^\]]*\]'), (m) => m[1]!)
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('`', '')
      .replaceAll(RegExp(r'\*\*|__|\*|~~'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  List<Section> _sections(
    List<(int, Heading?)> boundaries,
    List<String> refDefinitions,
  ) {
    final sections = <Section>[];
    for (var b = 0; b < boundaries.length; b++) {
      final (from, heading) = boundaries[b];
      final to = b + 1 < boundaries.length
          ? boundaries[b + 1].$1
          : lines.length;
      var body = lines.sublist(from, to).join('\n');
      if (heading == null && body.trim().isEmpty) continue;
      // Reference-style links may be defined in another section; every
      // section gets the definitions so links resolve wherever they are used.
      if (boundaries.length > 1 && refDefinitions.isNotEmpty) {
        body = '$body\n\n${refDefinitions.join('\n')}';
      }
      sections.add(Section(heading: heading, markdown: body));
    }
    return sections;
  }
}
