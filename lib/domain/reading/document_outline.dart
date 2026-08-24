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

  static String _plainText(String inline) => _InlinePlainText(inline).read();

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

/// Resolves enough inline grammar for the outline to name the same heading the
/// page presents, without pulling a Markdown package into the domain ring.
///
/// Backslash escapes need one deliberate ordering rule. Code spans and
/// autolinks are literal regions, where a backslash stays a backslash. They are
/// therefore set aside before escaped ASCII punctuation is exposed as reading
/// text. Actual Markdown structure is removed afterwards, so `\*literal\*`
/// keeps its stars while `\\*emphasis*` keeps one slash and loses only the
/// genuine emphasis delimiters.
final class _InlinePlainText {
  final String source;

  _InlinePlainText(this.source);

  String read() {
    final literals = _InlineLiterals(source);
    var text = _protectCodeSpans(source, literals);
    text = _protectAutolinks(text, literals);
    text = _protectEscapedPunctuation(text, literals);
    text = text
        .replaceAllMapped(RegExp(r'!\[([^\]]*)\]\([^)]*\)'), (m) => m[1]!)
        .replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]*\)'), (m) => m[1]!)
        .replaceAllMapped(RegExp(r'\[([^\]]+)\]\[[^\]]*\]'), (m) => m[1]!)
        .replaceAll(RegExp(r'<[^>]+>'), '');
    text = _stripPairedMarks(text);
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return literals.restore(normalized);
  }

  static String _protectCodeSpans(String text, _InlineLiterals literals) {
    final result = StringBuffer();
    var cursor = 0;
    while (cursor < text.length) {
      if (text.codeUnitAt(cursor) != 0x60 || _isEscaped(text, cursor)) {
        result.writeCharCode(text.codeUnitAt(cursor++));
        continue;
      }

      final openingLength = _backtickRunAt(text, cursor);
      final closing = _matchingBacktickRun(
        text,
        cursor + openingLength,
        openingLength,
      );
      if (closing == -1) {
        result.write(text.substring(cursor, cursor + openingLength));
        cursor += openingLength;
        continue;
      }

      var content = text
          .substring(cursor + openingLength, closing)
          .replaceAll('\r\n', ' ')
          .replaceAll(RegExp(r'[\r\n]'), ' ');
      if (content.length >= 2 &&
          content.startsWith(' ') &&
          content.endsWith(' ') &&
          content.trim().isNotEmpty) {
        content = content.substring(1, content.length - 1);
      }
      result.write(literals.keep(content));
      cursor = closing + openingLength;
    }
    return result.toString();
  }

  static int _matchingBacktickRun(String text, int from, int length) {
    var cursor = from;
    while (cursor < text.length) {
      if (text.codeUnitAt(cursor) != 0x60) {
        cursor++;
        continue;
      }
      final run = _backtickRunAt(text, cursor);
      if (run == length) return cursor;
      cursor += run;
    }
    return -1;
  }

  static int _backtickRunAt(String text, int from) {
    var end = from;
    while (end < text.length && text.codeUnitAt(end) == 0x60) {
      end++;
    }
    return end - from;
  }

  static String _protectAutolinks(String text, _InlineLiterals literals) {
    final uri = RegExp(r'<([A-Za-z][A-Za-z0-9+.-]{1,31}:[^<>\x00-\x20]*)>');
    final email = RegExp(
      r"<([A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9.-]*[A-Za-z0-9])?)>",
    );
    return _replaceUnescapedMatches(
      _replaceUnescapedMatches(text, uri, (match) => literals.keep(match[1]!)),
      email,
      (match) => literals.keep(match[1]!),
    );
  }

  static String _replaceUnescapedMatches(
    String text,
    RegExp pattern,
    String Function(RegExpMatch match) replacement,
  ) {
    final result = StringBuffer();
    var cursor = 0;
    for (final match in pattern.allMatches(text)) {
      if (_isEscaped(text, match.start)) continue;
      result
        ..write(text.substring(cursor, match.start))
        ..write(replacement(match));
      cursor = match.end;
    }
    result.write(text.substring(cursor));
    return result.toString();
  }

  static bool _isEscaped(String text, int offset) {
    var slashes = 0;
    for (
      var cursor = offset - 1;
      cursor >= 0 && text.codeUnitAt(cursor) == 0x5c;
      cursor--
    ) {
      slashes++;
    }
    return slashes.isOdd;
  }

  static String _protectEscapedPunctuation(
    String text,
    _InlineLiterals literals,
  ) {
    final result = StringBuffer();
    var cursor = 0;
    while (cursor < text.length) {
      final current = text.codeUnitAt(cursor);
      if (current == 0x5c && cursor + 1 < text.length) {
        final next = text.codeUnitAt(cursor + 1);
        if (_isAsciiPunctuation(next)) {
          result.write(literals.keep(String.fromCharCode(next)));
          cursor += 2;
          continue;
        }
      }
      result.writeCharCode(current);
      cursor++;
    }
    return result.toString();
  }

  static bool _isAsciiPunctuation(int codeUnit) =>
      (codeUnit >= 0x21 && codeUnit <= 0x2f) ||
      (codeUnit >= 0x3a && codeUnit <= 0x40) ||
      (codeUnit >= 0x5b && codeUnit <= 0x60) ||
      (codeUnit >= 0x7b && codeUnit <= 0x7e);

  static String _stripPairedMarks(String text) {
    var result = text;
    for (final pattern in [
      RegExp(r'\*\*(.+?)\*\*', dotAll: true),
      RegExp(r'__(.+?)__', dotAll: true),
      RegExp(r'~~(.+?)~~', dotAll: true),
      RegExp(r'\*(.+?)\*', dotAll: true),
    ]) {
      result = result.replaceAllMapped(pattern, (match) => match[1]!);
    }
    return result;
  }
}

/// A collision-free placeholder store for source fragments whose grammar has
/// already been resolved. The marker is chosen from a private-use sequence
/// absent from this heading, so even deliberately hostile Unicode input is
/// restored exactly.
final class _InlineLiterals {
  final String _marker;
  final List<String> _values = [];

  _InlineLiterals(String source) : _marker = _markerAbsentFrom(source);

  String keep(String value) {
    final token = '$_marker${_values.length}$_marker';
    _values.add(value);
    return token;
  }

  String restore(String text) {
    var restored = text;
    for (var index = _values.length - 1; index >= 0; index--) {
      restored = restored.replaceAll('$_marker$index$_marker', _values[index]);
    }
    return restored;
  }

  static String _markerAbsentFrom(String source) {
    var marker = '\ue000';
    while (source.contains(marker)) {
      marker += '\ue001';
    }
    return marker;
  }
}
