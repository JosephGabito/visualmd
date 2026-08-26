import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html;

/// Reduces raw HTML to content a reading page can carry without becoming one.
///
/// Parsing a fragment builds an inert Dart tree; it does not create a browser
/// element or run script. Safe containers contribute only their words, while
/// tags whose parsing rules can change or execute a document remain visible as
/// authored source. Presentation never receives a DOM node, attribute, style,
/// event handler, or executable URL.
abstract final class SafeHtmlText {
  /// GFM's tagfilter list. These elements alter how an HTML document is parsed
  /// or admit an embedded browsing surface, so flattening them would conceal
  /// the dangerous instruction while preserving only its payload.
  static const disallowedTags = {
    'title',
    'textarea',
    'style',
    'xmp',
    'iframe',
    'noembed',
    'noframes',
    'script',
    'plaintext',
  };

  static const _blockBoundaries = {
    'address',
    'article',
    'aside',
    'base',
    'basefont',
    'blockquote',
    'body',
    'caption',
    'center',
    'col',
    'colgroup',
    'dd',
    'details',
    'dialog',
    'dir',
    'div',
    'dl',
    'dt',
    'fieldset',
    'figcaption',
    'figure',
    'footer',
    'form',
    'frame',
    'frameset',
    'h1',
    'h2',
    'h3',
    'h4',
    'h5',
    'h6',
    'header',
    'head',
    'hgroup',
    'html',
    'li',
    'legend',
    'link',
    'main',
    'menu',
    'menuitem',
    'nav',
    'noframes',
    'ol',
    'optgroup',
    'option',
    'p',
    'param',
    'pre',
    'search',
    'section',
    'source',
    'summary',
    'table',
    'tbody',
    'td',
    'tfoot',
    'th',
    'thead',
    'tr',
    'track',
    'ul',
  };

  static final _tagName = RegExp(
    r'^</?\s*([A-Za-z][A-Za-z0-9-]*)',
    caseSensitive: false,
  );

  static const _semanticInlineTags = {
    'sub': SafeInlineHtmlMark.subscript,
    'sup': SafeInlineHtmlMark.superscript,
    'ins': SafeInlineHtmlMark.insertion,
  };

  /// Classifies one raw inline token by what it contributes to reading.
  ///
  /// Ordinary open and close tags are formatting syntax. Their text lives in
  /// adjacent Markdown nodes and remains visible there. Comments intentionally
  /// return null as well, because they are authoring notes rather than reading
  /// content.
  static InlineHtmlReading inline(String source) {
    if (source.startsWith('<!--')) return const HiddenInlineHtml();
    final name = _tagName.firstMatch(source)?[1]?.toLowerCase();
    if (name != null && disallowedTags.contains(name)) {
      return VisibleInlineHtml(source);
    }
    final mark = _semanticInlineTags[name];
    if (mark != null && !RegExp(r'/\s*>$').hasMatch(source)) {
      return SemanticInlineHtml(
        mark: mark,
        closing: RegExp(r'^<\s*/').hasMatch(source),
      );
    }

    // Processing instructions, declarations and CDATA are not reading marks.
    // Unlike a harmless container tag, dropping one would erase its payload.
    if (source.startsWith('<?') ||
        source.startsWith('<!') && !source.startsWith('<!--')) {
      return VisibleInlineHtml(source);
    }
    if (name == 'br' || name == 'hr' || _blockBoundaries.contains(name)) {
      return const BreakInlineHtml();
    }
    return const HiddenInlineHtml();
  }

  /// Returns readable text for one raw HTML block, or null for comments only.
  static String? block(String source) {
    try {
      final protected = _ProtectedHtmlSource.from(source);
      final fragment = html.parseFragment(protected.text);
      if (_containsDisallowedElement(fragment.nodes)) return source;

      final buffer = _ReadingTextBuffer();
      for (final node in fragment.nodes) {
        _append(node, buffer, protected);
      }
      final text = buffer.text;
      return text.isEmpty ? null : text;
    } on Object {
      // An unexpected parser failure must keep the author's content visible.
      // Ordinary malformed HTML follows HTML5's defined recovery rules and
      // still contributes whatever readable text that recovery produces.
      return source.trim().isEmpty ? null : source;
    }
  }

  static bool _containsDisallowedElement(Iterable<dom.Node> nodes) {
    for (final node in nodes) {
      if (node is dom.Element &&
          disallowedTags.contains((node.localName ?? '').toLowerCase())) {
        return true;
      }
      if (_containsDisallowedElement(node.nodes)) return true;
    }
    return false;
  }

  static void _append(
    dom.Node node,
    _ReadingTextBuffer buffer,
    _ProtectedHtmlSource protected,
  ) {
    switch (node) {
      case dom.Comment():
        final opaqueSource = protected.sourceFor(node);
        if (opaqueSource != null) buffer.writeLiteral(opaqueSource);
        return;
      case dom.Text():
        buffer.write(node.data);
      case dom.Element():
        final name = (node.localName ?? '').toLowerCase();
        final boundary = _blockBoundaries.contains(name);
        if (boundary || name == 'br' || name == 'hr') buffer.breakLine();
        for (final child in node.nodes) {
          _append(child, buffer, protected);
        }
        if (boundary) buffer.breakLine();
      default:
        // Declarations and other non-element nodes carry no reading text.
        return;
    }
  }
}

/// Protects source that HTML5 fragment parsing would repair or reinterpret.
///
/// CommonMark may merge immediately adjacent raw HTML forms into one block.
/// A block-wide danger check would then either expose harmless tags and
/// comments or erase a later processing instruction. Replacing only opaque
/// spans with source-unique comments lets the inert parser reduce everything
/// around them independently. HTML5 preserves comments even in restrictive
/// select and table insertion modes, and the DOM walk recognizes that node
/// directly, so flattened text can never impersonate a placeholder.
final class _ProtectedHtmlSource {
  _ProtectedHtmlSource._(this.text, this._commentPrefix, this._sources);

  factory _ProtectedHtmlSource.from(String source) {
    final output = StringBuffer();
    final commentPrefix = _uniqueCommentPrefix(source);
    final sources = <String>[];
    var cursor = 0;
    var searchFrom = 0;

    while (searchFrom < source.length) {
      final start = source.indexOf('<', searchFrom);
      if (start < 0) break;

      if (source.startsWith('<!--', start)) {
        final close = source.indexOf('-->', start + 4);
        searchFrom = close < 0 ? source.length : close + 3;
        continue;
      }

      final end = _opaqueEnd(source, start);
      if (end == null) {
        // A harmless tag may contain HTML-looking text inside an attribute.
        // Attributes never contribute reading content, so skip the complete
        // quoted token rather than mistaking that private value for markup.
        searchFrom = _tagEnd(source, start) ?? start + 1;
        continue;
      }

      output.write(source.substring(cursor, start));
      final index = sources.length;
      output.write('<!--$commentPrefix:$index-->');
      sources.add(source.substring(start, end));
      cursor = end;
      searchFrom = end;
    }

    output.write(source.substring(cursor));
    return _ProtectedHtmlSource._(output.toString(), commentPrefix, sources);
  }

  final String text;
  final String _commentPrefix;
  final List<String> _sources;

  String? sourceFor(dom.Comment comment) {
    final prefix = '$_commentPrefix:';
    final data = comment.data;
    if (data == null || !data.startsWith(prefix)) return null;
    final index = int.tryParse(data.substring(prefix.length));
    if (index == null || index < 0 || index >= _sources.length) return null;
    return _sources[index];
  }

  static int? _opaqueEnd(String source, int start) {
    if (source.startsWith('<?', start)) {
      return _through(source, '?>', start + 2);
    }
    if (source.startsWith('<![CDATA[', start)) {
      return _through(source, ']]>', start + 9);
    }
    if (source.startsWith('<!', start)) {
      final declaration = RegExp(
        r'<![A-Za-z]',
        caseSensitive: false,
      ).matchAsPrefix(source, start);
      if (declaration != null) return _through(source, '>', declaration.end);
    }

    final tokenEnd = _tagEnd(source, start);
    if (tokenEnd == null) return null;
    final token = source.substring(start, tokenEnd);
    final name = SafeHtmlText._tagName.firstMatch(token)?[1]?.toLowerCase();
    if (name == null || !SafeHtmlText.disallowedTags.contains(name)) {
      return null;
    }
    if (token.startsWith('</') || token.trimRight().endsWith('/>')) {
      return tokenEnd;
    }

    final close = RegExp(
      '</\\s*${RegExp.escape(name)}\\s*>',
      caseSensitive: false,
    ).firstMatch(source.substring(tokenEnd));
    return close == null ? source.length : tokenEnd + close.end;
  }

  static int? _tagEnd(String source, int start) {
    var quote = 0;
    for (var index = start + 1; index < source.length; index++) {
      final code = source.codeUnitAt(index);
      if (quote != 0) {
        if (code == quote) quote = 0;
        continue;
      }
      if (code == 0x22 || code == 0x27) {
        quote = code;
      } else if (code == 0x3e) {
        return index + 1;
      }
    }
    return null;
  }

  static int _through(String source, String closing, int from) {
    final close = source.indexOf(closing, from);
    return close < 0 ? source.length : close + closing.length;
  }

  static String _uniqueCommentPrefix(String source) {
    var suffix = 0;
    while (true) {
      final prefix = 'visual-md-opaque-$suffix';
      if (!source.contains(prefix)) return prefix;
      suffix++;
    }
  }
}

/// What one raw inline HTML token contributes to the reading stream.
sealed class InlineHtmlReading {
  const InlineHtmlReading();
}

/// Formatting syntax or an authoring comment with no visible contribution.
final class HiddenInlineHtml extends InlineHtmlReading {
  const HiddenInlineHtml();
}

/// Source that must remain visible because flattening it would conceal intent.
final class VisibleInlineHtml extends InlineHtmlReading {
  const VisibleInlineHtml(this.source);

  final String source;
}

/// A structural boundary that separates the words on either side of it.
final class BreakInlineHtml extends InlineHtmlReading {
  const BreakInlineHtml();
}

/// One safe GitHub writing mark whose attributes have already been discarded.
final class SemanticInlineHtml extends InlineHtmlReading {
  const SemanticInlineHtml({required this.mark, required this.closing});

  final SafeInlineHtmlMark mark;
  final bool closing;
}

enum SafeInlineHtmlMark { subscript, superscript, insertion }

/// Collapses source formatting whitespace without changing punctuation edges.
///
/// A pending separator crosses harmless inline tags, so `one <b>two</b>` keeps
/// its space. No separator is invented when the source had none, so
/// `<b>word</b>.` remains `word.`. Keeping the last-state flags alongside the
/// buffer also makes the walk linear instead of repeatedly copying its prefix.
final class _ReadingTextBuffer {
  static final _whitespace = RegExp(r'\s+');

  final _buffer = StringBuffer();
  var _empty = true;
  var _atLineStart = true;
  var _pendingSpace = false;

  void write(String source) {
    var cursor = 0;
    for (final match in _whitespace.allMatches(source)) {
      _writeChunk(source.substring(cursor, match.start));
      _pendingSpace = true;
      cursor = match.end;
    }
    _writeChunk(source.substring(cursor));
  }

  void _writeChunk(String chunk) {
    if (chunk.isEmpty) return;
    if (_pendingSpace && !_empty && !_atLineStart) _buffer.write(' ');
    _buffer.write(chunk);
    _empty = false;
    _atLineStart = false;
    _pendingSpace = false;
  }

  /// Writes protected authored syntax without normalising its interior.
  void writeLiteral(String source) {
    if (source.isEmpty) return;
    if (_pendingSpace && !_empty && !_atLineStart) _buffer.write(' ');
    _buffer.write(source);
    _empty = false;
    _atLineStart = source.endsWith('\n');
    _pendingSpace = false;
  }

  void breakLine() {
    _pendingSpace = false;
    if (_empty || _atLineStart) return;
    _buffer.write('\n');
    _atLineStart = true;
  }

  String get text {
    final value = _buffer.toString();
    return value.endsWith('\n') ? value.substring(0, value.length - 1) : value;
  }
}
