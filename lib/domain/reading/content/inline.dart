/// The run-level content of a document: what a line of text is made of.
///
/// Pure text as the Markdown grammar resolves it. Authorial punctuation and
/// internal spacing remain source; formatting whitespace such as a soft line
/// break has already become the reading text it represents. How that text is
/// *set* — which quote marks, which figures, which face — is decided later.
sealed class Inline {
  const Inline();

  /// The plain text of this run and everything inside it, for outlines,
  /// search and anything else that needs words without decoration.
  String get text;
}

final class TextRun extends Inline {
  @override
  final String text;

  const TextRun(this.text);

  @override
  bool operator ==(Object other) => other is TextRun && other.text == text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'TextRun("$text")';
}

/// Verbatim: never re-set, never re-punctuated, never re-wrapped.
final class CodeRun extends Inline {
  @override
  final String text;

  const CodeRun(this.text);

  @override
  bool operator ==(Object other) => other is CodeRun && other.text == text;

  @override
  int get hashCode => text.hashCode;
}

/// An equation that belongs to the sentence around it.
///
/// Delimiters are Markdown grammar and have already been removed. [source]
/// is the exact TeX between them; presentation decides how to typeset it and
/// must be able to fall back to this value when it cannot.
final class MathRun extends Inline {
  final String source;

  const MathRun(this.source);

  @override
  String get text => source;

  @override
  bool operator ==(Object other) => other is MathRun && other.source == source;

  @override
  int get hashCode => source.hashCode;
}

/// A run that carries a reading mark over the runs inside it.
final class MarkedRun extends Inline {
  final InlineMark mark;
  final List<Inline> children;

  const MarkedRun(this.mark, this.children);

  @override
  String get text => children.map((c) => c.text).join();
}

enum InlineMark {
  emphasis,
  strong,
  strikethrough,
  subscript,
  superscript,
  insertion,
}

final class LinkRun extends Inline {
  final String href;
  final String? title;
  final List<Inline> children;

  const LinkRun({required this.href, this.title, required this.children});

  @override
  String get text => children.map((c) => c.text).join();
}

final class ImageRun extends Inline {
  final String source;
  final String? title;
  final String alt;
  final List<ThemedImageSource> themedSources;

  const ImageRun({
    required this.source,
    this.title,
    required this.alt,
    this.themedSources = const [],
  });

  /// The first authored source for [scheme], or the required fallback image.
  ///
  /// HTML `picture` selection is ordered. Keeping that order here means the
  /// page can respond to a theme change without reparsing the document, while
  /// unsupported media queries never acquire meaning in the domain.
  String sourceFor(ImageColorScheme scheme) =>
      themedSources
          .where((candidate) => candidate.scheme == scheme)
          .map((candidate) => candidate.source)
          .firstOrNull ??
      source;

  @override
  String get text => alt;
}

/// One safe `picture` candidate whose only condition is reading appearance.
final class ThemedImageSource {
  final ImageColorScheme scheme;
  final String source;

  const ThemedImageSource({required this.scheme, required this.source});
}

enum ImageColorScheme { light, dark }

/// A line the author asked for, with two or more spaces or a backslash.
///
/// An ordinary source newline is not one of these: it is formatting for the
/// source file, resolved into reading text before the domain sees it.
final class LineBreakRun extends Inline {
  const LineBreakRun();

  @override
  String get text => '\n';
}
