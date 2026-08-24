/// The colour family a highlighter should prepare for.
///
/// This is Visual MD's vocabulary rather than Flutter's [Brightness], keeping
/// the contribution contract usable without a rendering framework.
enum CodeHighlightScheme { light, dark }

/// The meaning carried by a highlighted run.
///
/// The renderer may use this when a contributed colour is absent or unsuitable
/// for the active reading surface. A token therefore remains semantic data,
/// not a package-specific styled span.
enum CodeTokenRole {
  plain,
  comment,
  keyword,
  string,
  number,
  type,
  function,
  variable,
  property,
  tag,
  attribute,
  punctuation,
  inserted,
  deleted,
}

/// One source range that shares a syntactic role and suggested foreground.
final class CodeHighlightToken {
  final int start;
  final int end;
  final CodeTokenRole role;

  /// A CSS-style hexadecimal colour, or null when the page should use its
  /// ordinary code colour. It is data rather than a renderer or package type.
  final String? foreground;

  const CodeHighlightToken({
    required this.start,
    required this.end,
    required this.role,
    this.foreground,
  }) : assert(start >= 0),
       assert(end > start);
}

/// Highlighting for the exact source string supplied to [CodeHighlighter].
final class CodeHighlighting {
  final List<CodeHighlightToken> tokens;

  const CodeHighlighting(this.tokens);
}

/// Adds syntax meaning to fenced source without owning how it is rendered.
///
/// Null is an ordinary result: plain text, an unknown language, or a failed
/// grammar all leave the author's exact source visible through the reader's
/// built-in fallback.
abstract interface class CodeHighlighter {
  String labelFor(String? language);

  Future<CodeHighlighting?> highlight({
    required String source,
    required String? language,
    required CodeHighlightScheme scheme,
  });
}

/// The kernel fallback used when no syntax contributor is registered.
final class PlainCodeHighlighter implements CodeHighlighter {
  const PlainCodeHighlighter();

  @override
  String labelFor(String? language) {
    final name = _languageName(language);
    return name ?? 'Text';
  }

  @override
  Future<CodeHighlighting?> highlight({
    required String source,
    required String? language,
    required CodeHighlightScheme scheme,
  }) async => null;
}

String? _languageName(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) return null;
  return trimmed.split(RegExp(r'\s+')).first;
}
