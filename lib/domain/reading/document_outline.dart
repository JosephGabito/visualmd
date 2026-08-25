import 'character_references.dart';
import 'heading_anchor.dart';
import 'heading.dart';
import 'link_reference_definitions.dart';
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
  static final _refDefinition = RegExp(r'^ {0,3}\[[^\]]+\]:');
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
    final references = LinkReferenceDefinitions.fromLines(lines, start);
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

      if (references.ownsLine(i)) {
        i++;
        continue;
      }

      final atx = _atx.firstMatch(line);
      if (atx != null) {
        final heading = _heading(atx[1]!.length, atx[2] ?? '', i, references);
        headings.add(heading);
        boundaries.add((i, heading));
        i++;
        continue;
      }

      final setext = _setextStartingAt(i);
      if (setext != null) {
        final heading = _heading(setext.level, setext.source, i, references);
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
      sections: List.unmodifiable(_sections(boundaries)),
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

  Heading _heading(
    int level,
    String raw,
    int line,
    LinkReferenceDefinitions references,
  ) {
    var text = raw.trim();
    final closing = _closingHashes.firstMatch(text);
    if (closing != null) text = closing[1]!;
    if (RegExp(r'^#+$').hasMatch(text)) text = '';
    text = _plainText(text, references);
    return Heading(
      level: level,
      text: text,
      anchor: _anchors.take(text),
      line: line,
    );
  }

  static String _plainText(
    String inline,
    LinkReferenceDefinitions references,
  ) => _InlinePlainText(inline, references).read();

  List<Section> _sections(List<(int, Heading?)> boundaries) {
    final sections = <Section>[];
    for (var b = 0; b < boundaries.length; b++) {
      final (from, heading) = boundaries[b];
      final to = b + 1 < boundaries.length
          ? boundaries[b + 1].$1
          : lines.length;
      final body = lines.sublist(from, to).join('\n');
      if (heading == null && body.trim().isEmpty) continue;
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
/// genuine emphasis delimiters. Character references resolve only after that
/// structure has been removed, so an encoded asterisk remains text instead of
/// becoming a delimiter the source never authored.
final class _InlinePlainText {
  final String source;
  final LinkReferenceDefinitions references;

  _InlinePlainText(this.source, this.references);

  String read() {
    final literals = _InlineLiterals(source);
    var text = _resolveReferenceLinks(source, references);
    text = _protectCodeSpans(text, literals);
    text = _protectAutolinks(text, literals);
    text = _protectEscapedPunctuation(text, literals);
    text = text
        .replaceAllMapped(RegExp(r'!\[([^\]]*)\]\([^)]*\)'), (m) => m[1]!)
        .replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]*\)'), (m) => m[1]!);
    text = text.replaceAll(RegExp(r'<[^>]+>'), '');
    text = _stripPairedMarks(text, literals);
    text = CharacterReferences.decode(text);
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return literals.restore(normalized);
  }

  /// Reference notation disappears only when the document actually defines
  /// its label. An unresolved form is authored text and must remain visible in
  /// the outline exactly as it does on the page.
  static String _resolveReferenceLinks(
    String text,
    LinkReferenceDefinitions references,
  ) {
    final result = StringBuffer();
    var cursor = 0;
    while (cursor < text.length) {
      if (text.codeUnitAt(cursor) != 0x5b || _isEscaped(text, cursor)) {
        result.writeCharCode(text.codeUnitAt(cursor++));
        continue;
      }

      final textEnd = _matchingBracket(text, cursor);
      if (textEnd == -1) {
        result.writeCharCode(text.codeUnitAt(cursor++));
        continue;
      }
      final visible = text.substring(cursor + 1, textEnd);
      final labelStart = textEnd + 1;

      if (labelStart < text.length && text.codeUnitAt(labelStart) == 0x28) {
        result.write(text.substring(cursor, textEnd + 1));
        cursor = textEnd + 1;
        continue;
      } else if (labelStart < text.length &&
          text.codeUnitAt(labelStart) == 0x5b) {
        final labelEnd = _referenceLabelEnd(text, labelStart);
        if (labelEnd != -1) {
          final explicit = text.substring(labelStart + 1, labelEnd);
          final label = explicit.isEmpty ? visible : explicit;
          if (references.contains(label)) {
            result.write(visible);
            cursor = labelEnd + 1;
            continue;
          }
        }
      } else if (references.contains(visible)) {
        result.write(visible);
        cursor = textEnd + 1;
        continue;
      }

      result.write(text.substring(cursor, textEnd + 1));
      cursor = textEnd + 1;
    }
    return result.toString();
  }

  static int _matchingBracket(String text, int opening) {
    var depth = 1;
    for (var cursor = opening + 1; cursor < text.length; cursor++) {
      if (_isEscaped(text, cursor)) continue;
      final character = text.codeUnitAt(cursor);
      if (character == 0x5b) {
        depth++;
      } else if (character == 0x5d && --depth == 0) {
        return cursor;
      }
    }
    return -1;
  }

  static int _referenceLabelEnd(String text, int opening) {
    var characters = 0;
    for (var cursor = opening + 1; cursor < text.length; cursor++) {
      final character = text.codeUnitAt(cursor);
      if (character == 0x5c && cursor + 1 < text.length) {
        cursor++;
        characters += 2;
      } else if (character == 0x5b) {
        return -1;
      } else if (character == 0x5d) {
        final label = text.substring(opening + 1, cursor);
        return characters <= 999 &&
                (label.isEmpty || RegExp(r'\S').hasMatch(label))
            ? cursor
            : -1;
      } else {
        characters++;
      }
      if (characters > 999) return -1;
    }
    return -1;
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

  static String _stripPairedMarks(String text, _InlineLiterals literals) {
    return _MarkedPlainText(text, literals).read();
  }
}

/// Removes only the delimiter characters that CommonMark and GFM resolve.
///
/// A regex cannot do this recursively: `**outer _inner_**` needs another pass,
/// while `*foo**bar*` must keep its interior pair under the rule of three. The
/// outline does not need the resulting mark tree, but it does need the same
/// delimiter-run decisions as the page so titles and anchors name what is read.
final class _MarkedPlainText {
  static final _punctuationOrSymbol = RegExp(r'^[\p{P}\p{S}]$', unicode: true);
  static final _whitespace = RegExp(r'^(?:\p{Zs}|[\t\n\f\r])$', unicode: true);

  final String source;
  final _InlineLiterals literals;

  _MarkedPlainText(this.source, this.literals);

  String read() {
    final atoms = _atoms();
    final delimiters = atoms.whereType<_MarkedDelimiter>().toList();
    _resolve(delimiters);
    return atoms.map((atom) => atom.output).join();
  }

  List<_MarkedAtom> _atoms() {
    final atoms = <_MarkedAtom>[];
    var cursor = 0;
    while (cursor < source.length) {
      final kept = literals.tokenAt(source, cursor);
      if (kept != null) {
        atoms.add(_MarkedText(kept.token, edgeText: kept.value));
        cursor += kept.token.length;
        continue;
      }

      final codeUnit = source.codeUnitAt(cursor);
      final width =
          codeUnit >= 0xd800 &&
              codeUnit <= 0xdbff &&
              cursor + 1 < source.length &&
              source.codeUnitAt(cursor + 1) >= 0xdc00 &&
              source.codeUnitAt(cursor + 1) <= 0xdfff
          ? 2
          : 1;
      if (codeUnit == 0x2a || codeUnit == 0x5f || codeUnit == 0x7e) {
        final character = String.fromCharCode(codeUnit);
        var end = cursor + 1;
        while (end < source.length && source.codeUnitAt(end) == codeUnit) {
          end++;
        }
        final length = end - cursor;
        if (character == '~' && length > 2) {
          // GFM makes the entire run literal; it cannot donate a shorter pair.
          atoms.add(_MarkedText(source.substring(cursor, end)));
        } else {
          atoms.add(_MarkedDelimiter(character, length));
        }
        cursor = end;
      } else {
        atoms.add(_MarkedText(source.substring(cursor, cursor + width)));
        cursor += width;
      }
    }

    for (var index = 0; index < atoms.length; index++) {
      final delimiter = atoms[index];
      if (delimiter is! _MarkedDelimiter) continue;
      final before = index == 0 ? null : _lastScalar(atoms[index - 1].edge);
      final after = index + 1 == atoms.length
          ? null
          : _firstScalar(atoms[index + 1].edge);
      delimiter.classify(before: before, after: after);
    }
    return atoms;
  }

  static String? _firstScalar(String text) {
    if (text.isEmpty) return null;
    return String.fromCharCode(text.runes.first);
  }

  static String? _lastScalar(String text) {
    if (text.isEmpty) return null;
    return String.fromCharCode(text.runes.last);
  }

  static bool _isWhitespace(String? scalar) =>
      scalar == null || _whitespace.hasMatch(scalar);

  static bool _isPunctuation(String? scalar) =>
      scalar != null && _punctuationOrSymbol.hasMatch(scalar);

  static void _resolve(List<_MarkedDelimiter> stack) {
    var current = 0;
    final openersBottom = <String, List<int>>{};
    while (current < stack.length) {
      final closer = stack[current];
      if (!closer.canClose) {
        current++;
        continue;
      }

      final bottoms = openersBottom.putIfAbsent(
        closer.character,
        () => List.filled(3, -1),
      );
      final bottom = bottoms[closer.remaining % 3];
      var openerIndex = -1;
      for (var candidate = current - 1; candidate > bottom; candidate--) {
        final opener = stack[candidate];
        if (opener.character == closer.character &&
            opener.canOpen &&
            _canFormMark(opener, closer)) {
          openerIndex = candidate;
          break;
        }
      }

      if (openerIndex == -1) {
        bottoms[closer.remaining % 3] = current - 1;
        if (closer.canOpen) {
          current++;
        } else {
          stack.removeAt(current);
        }
        continue;
      }

      final opener = stack[openerIndex];
      final used = opener.remaining >= 2 && closer.remaining >= 2 ? 2 : 1;
      if (current > openerIndex + 1) {
        stack.removeRange(openerIndex + 1, current);
      }
      current = openerIndex + 1;
      opener.remaining -= used;
      closer.remaining -= used;

      if (opener.remaining == 0) {
        stack.removeAt(openerIndex);
        current--;
      }
      if (closer.remaining == 0) {
        stack.removeAt(current);
      }
    }
  }

  static bool _canFormMark(_MarkedDelimiter opener, _MarkedDelimiter closer) {
    if (opener.character == '~') return true;
    if ((opener.canOpen && opener.canClose) ||
        (closer.canOpen && closer.canClose)) {
      return (opener.remaining + closer.remaining) % 3 != 0 ||
          (opener.remaining % 3 == 0 && closer.remaining % 3 == 0);
    }
    return true;
  }
}

sealed class _MarkedAtom {
  String get output;
  String get edge;
}

final class _MarkedText implements _MarkedAtom {
  final String source;
  final String edgeText;

  _MarkedText(this.source, {String? edgeText}) : edgeText = edgeText ?? source;

  @override
  String get output => source;

  @override
  String get edge => edgeText;
}

final class _MarkedDelimiter implements _MarkedAtom {
  final String character;
  int remaining;
  bool canOpen = false;
  bool canClose = false;

  _MarkedDelimiter(this.character, int length) : remaining = length;

  void classify({required String? before, required String? after}) {
    final beforeWhitespace = _MarkedPlainText._isWhitespace(before);
    final afterWhitespace = _MarkedPlainText._isWhitespace(after);
    final beforePunctuation = _MarkedPlainText._isPunctuation(before);
    final afterPunctuation = _MarkedPlainText._isPunctuation(after);
    final leftFlanking =
        !afterWhitespace &&
        (!afterPunctuation || beforeWhitespace || beforePunctuation);
    final rightFlanking =
        !beforeWhitespace &&
        (!beforePunctuation || afterWhitespace || afterPunctuation);
    final allowIntraWord = character == '*' || character == '~';
    canOpen =
        leftFlanking && (!rightFlanking || allowIntraWord || beforePunctuation);
    canClose =
        rightFlanking && (!leftFlanking || allowIntraWord || afterPunctuation);
  }

  @override
  String get output => character * remaining;

  @override
  String get edge => character;
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

  ({String token, String value})? tokenAt(String text, int offset) {
    if (!text.startsWith(_marker, offset)) return null;
    final indexStart = offset + _marker.length;
    final indexEnd = text.indexOf(_marker, indexStart);
    if (indexEnd == -1) return null;
    final index = int.tryParse(text.substring(indexStart, indexEnd));
    if (index == null || index < 0 || index >= _values.length) return null;
    return (
      token: text.substring(offset, indexEnd + _marker.length),
      value: _values[index],
    );
  }

  static String _markerAbsentFrom(String source) {
    var marker = '\ue000';
    while (source.contains(marker)) {
      marker += '\ue001';
    }
    return marker;
  }
}
