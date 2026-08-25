import 'link_label.dart';

/// The reference labels a document defines, independent of where a link uses
/// them.
///
/// The page parser resolves the destination and title. The outline needs only
/// one fact: whether bracketed heading text is a real link whose notation must
/// disappear, or unresolved source whose brackets must remain visible.
final class LinkReferenceDefinitions {
  final Set<String> _labels;
  final Set<int> _sourceLines;

  const LinkReferenceDefinitions._(this._labels, this._sourceLines);

  factory LinkReferenceDefinitions.fromLines(List<String> lines, int start) {
    final labels = <String>{};
    final sourceLines = <int>{};
    String? fenceMarker;
    var priorDefinitionEndedAt = -2;

    for (var line = start; line < lines.length; line++) {
      final fence = _fence.firstMatch(lines[line]);
      if (fence != null) {
        final marker = fence[1]!;
        if (fenceMarker == null) {
          fenceMarker = marker;
        } else if (marker[0] == fenceMarker[0] &&
            marker.length >= fenceMarker.length) {
          fenceMarker = null;
        }
        continue;
      }
      if (fenceMarker != null ||
          !_mayStartAt(lines, line, start, priorDefinitionEndedAt)) {
        continue;
      }

      final definition = _Definition.tryParse(lines, line);
      if (definition == null) continue;
      labels.add(LinkLabel.normalize(definition.label));
      for (var owned = line; owned <= definition.lastLine; owned++) {
        sourceLines.add(owned);
      }
      priorDefinitionEndedAt = definition.lastLine;
      line = definition.lastLine;
    }

    return LinkReferenceDefinitions._(
      Set.unmodifiable(labels),
      Set.unmodifiable(sourceLines),
    );
  }

  bool contains(String sourceLabel) =>
      _labels.contains(LinkLabel.normalize(sourceLabel));

  bool ownsLine(int line) => _sourceLines.contains(line);

  static final _fence = RegExp(r'^ {0,3}(`{3,}|~{3,})');
  static final _atx = RegExp(r'^ {0,3}#{1,6}(?:[ \t]+|$)');
  static final _setext = RegExp(r'^ {0,3}(?:=+|-+)[ \t]*$');

  /// A definition is a block and therefore cannot interrupt ordinary prose.
  /// Blank lines, headings, and a preceding definition establish a new block.
  static bool _mayStartAt(
    List<String> lines,
    int line,
    int start,
    int priorDefinitionEndedAt,
  ) {
    if (line == start || priorDefinitionEndedAt == line - 1) return true;
    final previous = lines[line - 1];
    return previous.trim().isEmpty ||
        _atx.hasMatch(previous) ||
        _setext.hasMatch(previous);
  }
}

final class _Definition {
  final String label;
  final int lastLine;

  const _Definition(this.label, this.lastLine);

  static _Definition? tryParse(List<String> lines, int firstLine) {
    final first = lines[firstLine];
    final indentation = RegExp(r'^ {0,3}').firstMatch(first)![0]!.length;
    if (indentation == 4 ||
        indentation >= first.length ||
        first.codeUnitAt(indentation) != 0x5b) {
      return null;
    }

    var lastCandidate = firstLine;
    while (lastCandidate + 1 < lines.length &&
        lines[lastCandidate + 1].trim().isNotEmpty) {
      lastCandidate++;
    }
    final source = <String>[
      first.substring(indentation),
      ...lines.sublist(firstLine + 1, lastCandidate + 1),
    ].join('\n');
    final parser = _DefinitionParser(source);
    final result = parser.read();
    if (result == null) return null;
    return _Definition(result.label, firstLine + result.lastRelativeLine);
  }
}

final class _DefinitionParser {
  final String source;
  var _cursor = 0;

  _DefinitionParser(this.source);

  ({String label, int lastRelativeLine})? read() {
    final label = _label();
    if (label == null || !_take(0x3a)) return null;

    _horizontalSpace();
    if (_atNewline) {
      _cursor++;
      _horizontalSpace();
    }
    if (!_destination()) return null;
    final destinationEnd = _cursor;

    final spaces = _horizontalSpace();
    if (_done || _atNewline) {
      if (_atNewline) {
        final titleStart = _cursor + 1;
        _cursor = titleStart;
        _horizontalSpace();
        if (_title() && _onlyHorizontalSpaceToLineEnd()) {
          return (label: label, lastRelativeLine: _lineAt(_cursor));
        }
      }
      return (label: label, lastRelativeLine: _lineAt(destinationEnd));
    }

    if (spaces == 0 || !_title() || !_onlyHorizontalSpaceToLineEnd()) {
      return null;
    }
    return (label: label, lastRelativeLine: _lineAt(_cursor));
  }

  String? _label() {
    if (!_take(0x5b)) return null;
    final start = _cursor;
    var characters = 0;
    while (!_done) {
      final character = source.codeUnitAt(_cursor);
      if (character == 0x5c) {
        if (_cursor + 1 >= source.length) return null;
        _cursor += 2;
        characters += 2;
      } else if (character == 0x5b) {
        return null;
      } else if (character == 0x5d) {
        final label = source.substring(start, _cursor);
        _cursor++;
        return characters <= 999 && RegExp(r'\S').hasMatch(label)
            ? label
            : null;
      } else {
        _cursor++;
        characters++;
      }
      if (characters > 999) return null;
    }
    return null;
  }

  bool _destination() {
    if (_done || _atNewline) return false;
    if (source.codeUnitAt(_cursor) == 0x3c) {
      _cursor++;
      while (!_done && !_atNewline) {
        final character = source.codeUnitAt(_cursor);
        if (character == 0x5c && _cursor + 1 < source.length) {
          _cursor += 2;
        } else if (character == 0x3c) {
          return false;
        } else if (character == 0x3e) {
          _cursor++;
          return true;
        } else {
          _cursor++;
        }
      }
      return false;
    }

    final start = _cursor;
    var parentheses = 0;
    while (!_done) {
      final character = source.codeUnitAt(_cursor);
      if (character == 0x5c && _cursor + 1 < source.length) {
        _cursor += 2;
      } else if (_isWhitespace(character)) {
        break;
      } else if (character == 0x28) {
        parentheses++;
        _cursor++;
      } else if (character == 0x29) {
        if (parentheses == 0) break;
        parentheses--;
        _cursor++;
      } else {
        _cursor++;
      }
    }
    return _cursor > start && parentheses == 0;
  }

  bool _title() {
    if (_done) return false;
    final opener = source.codeUnitAt(_cursor);
    final closer = opener == 0x28 ? 0x29 : opener;
    if (opener != 0x22 && opener != 0x27 && opener != 0x28) return false;
    _cursor++;
    while (!_done) {
      final character = source.codeUnitAt(_cursor);
      if (character == 0x5c && _cursor + 1 < source.length) {
        _cursor += 2;
      } else if (character == closer) {
        _cursor++;
        return true;
      } else if (character == 0x0a &&
          (_cursor + 1 >= source.length ||
              source.codeUnitAt(_cursor + 1) == 0x0a)) {
        return false;
      } else {
        _cursor++;
      }
    }
    return false;
  }

  int _horizontalSpace() {
    final start = _cursor;
    while (!_done) {
      final character = source.codeUnitAt(_cursor);
      if (character != 0x20 && character != 0x09) break;
      _cursor++;
    }
    return _cursor - start;
  }

  bool _onlyHorizontalSpaceToLineEnd() {
    _horizontalSpace();
    return _done || _atNewline;
  }

  bool _take(int character) {
    if (_done || source.codeUnitAt(_cursor) != character) return false;
    _cursor++;
    return true;
  }

  int _lineAt(int offset) =>
      '\n'.allMatches(source.substring(0, offset)).length;

  bool get _done => _cursor >= source.length;
  bool get _atNewline => !_done && source.codeUnitAt(_cursor) == 0x0a;

  static bool _isWhitespace(int character) =>
      character == 0x20 ||
      character == 0x09 ||
      character == 0x0a ||
      character == 0x0d ||
      character == 0x0c;
}
