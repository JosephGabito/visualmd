import 'package:shiki_flutter/shiki_flutter.dart';

import '../../presentation/code/code_highlighter.dart';

/// The syntax contributor shipped with Visual MD.
///
/// Shiki is kept behind the presentation contract: its grammars, themes and
/// token objects end here. The reading renderer receives only source ranges,
/// semantic roles and suggested colours in Visual MD's own vocabulary.
final class ShikiCodeHighlighter implements CodeHighlighter {
  static const _plainNames = {'text', 'txt', 'plain', 'plaintext'};

  final ShikiHighlighter _engine;
  late final Map<String, _KnownLanguage> _languages = _buildCatalog();

  ShikiCodeHighlighter({ShikiHighlighter? engine})
    : _engine = engine ?? ShikiHighlighter();

  @override
  String labelFor(String? language) {
    final name = _languageName(language);
    if (name == null || _plainNames.contains(name)) return 'Text';
    return _languages[name]?.label ?? _firstWord(language)!;
  }

  @override
  Future<CodeHighlighting?> highlight({
    required String source,
    required String? language,
    required CodeHighlightScheme scheme,
  }) async {
    final name = _languageName(language);
    if (name == null || _plainNames.contains(name)) return null;
    final known = _languages[name];
    if (known == null) return null;

    final theme = scheme == CodeHighlightScheme.dark
        ? ShikiThemes.githubDarkDefault
        : ShikiThemes.githubLight;

    try {
      // Yield first so the exact plain source can paint before a cold grammar
      // is decoded. Tokenization itself then runs in Shiki's cached worker.
      await Future<void>.delayed(Duration.zero);
      _engine
        ..ensureLanguage(known.grammar)
        ..ensureShikiTheme(theme);
      final lines = await _engine.codeToTokensAsync(
        source,
        TokenizeOptions(
          lang: known.grammar.id,
          theme: theme.id,
          includeExplanation: true,
          // A generated one-line payload must remain reachable even when it is
          // too large to justify a grammar pass. Shiki emits it as plain text.
          tokenizeMaxLineLength: 20000,
        ),
      );

      final tokens = <CodeHighlightToken>[];
      for (final line in lines) {
        for (final token in line) {
          if (token.content.isEmpty) continue;
          final start = token.offset;
          final end = start + token.content.length;
          // A package update must never be allowed to alter or duplicate the
          // source. Invalid ranges are ignored and the raw gap stays visible.
          if (start < 0 || end > source.length) continue;
          if (source.substring(start, end) != token.content) continue;
          tokens.add(
            CodeHighlightToken(
              start: start,
              end: end,
              role: _roleOf(token.scopes),
              foreground: token.color,
            ),
          );
        }
      }
      tokens.sort((a, b) => a.start.compareTo(b.start));
      return CodeHighlighting(tokens);
    } catch (_) {
      // Highlighting is an enhancement, never a condition for reading code.
      return null;
    }
  }

  Map<String, _KnownLanguage> _buildCatalog() {
    final catalog = <String, _KnownLanguage>{};
    for (final known in _curatedLanguages) {
      for (final name in {
        known.grammar.id,
        ...known.grammar.aliases,
        ...known.aliases,
      }) {
        catalog[name.toLowerCase()] = known;
      }
    }
    return catalog;
  }

  static CodeTokenRole _roleOf(List<String>? scopes) {
    final value = (scopes ?? const <String>[]).join(' ').toLowerCase();
    if (value.contains('markup.inserted')) return CodeTokenRole.inserted;
    if (value.contains('markup.deleted')) return CodeTokenRole.deleted;
    if (value.contains('comment')) return CodeTokenRole.comment;
    if (value.contains('string')) return CodeTokenRole.string;
    if (value.contains('constant.numeric') || value.contains('number')) {
      return CodeTokenRole.number;
    }
    if (value.contains('keyword') || value.contains('storage.')) {
      return CodeTokenRole.keyword;
    }
    if (value.contains('entity.name.type') ||
        value.contains('support.type') ||
        value.contains('support.class')) {
      return CodeTokenRole.type;
    }
    if (value.contains('entity.name.function') ||
        value.contains('support.function')) {
      return CodeTokenRole.function;
    }
    if (value.contains('entity.name.tag') || value.contains('meta.tag')) {
      return CodeTokenRole.tag;
    }
    if (value.contains('entity.other.attribute')) {
      return CodeTokenRole.attribute;
    }
    if (value.contains('variable.other.property') ||
        value.contains('support.type.property')) {
      return CodeTokenRole.property;
    }
    if (value.contains('variable')) return CodeTokenRole.variable;
    if (value.contains('punctuation') || value.contains('operator')) {
      return CodeTokenRole.punctuation;
    }
    return CodeTokenRole.plain;
  }
}

final class _KnownLanguage {
  final CodeLanguage grammar;
  final String label;
  final List<String> aliases;

  const _KnownLanguage(this.grammar, this.label, [this.aliases = const []]);
}

const _curatedLanguages = <_KnownLanguage>[
  _KnownLanguage(CodeLanguages.html, 'HTML'),
  _KnownLanguage(CodeLanguages.css, 'CSS'),
  _KnownLanguage(CodeLanguages.scss, 'SCSS'),
  _KnownLanguage(CodeLanguages.javascript, 'JavaScript'),
  _KnownLanguage(CodeLanguages.typescript, 'TypeScript'),
  _KnownLanguage(CodeLanguages.jsx, 'JSX'),
  _KnownLanguage(CodeLanguages.tsx, 'TSX'),
  _KnownLanguage(CodeLanguages.php, 'PHP'),
  _KnownLanguage(CodeLanguages.python, 'Python'),
  _KnownLanguage(CodeLanguages.dart, 'Dart'),
  _KnownLanguage(CodeLanguages.swift, 'Swift'),
  _KnownLanguage(CodeLanguages.kotlin, 'Kotlin'),
  _KnownLanguage(CodeLanguages.java, 'Java'),
  _KnownLanguage(CodeLanguages.csharp, 'C#', ['c#']),
  _KnownLanguage(CodeLanguages.ruby, 'Ruby'),
  _KnownLanguage(CodeLanguages.c, 'C'),
  _KnownLanguage(CodeLanguages.cpp, 'C++', ['c++']),
  _KnownLanguage(CodeLanguages.rust, 'Rust'),
  _KnownLanguage(CodeLanguages.go, 'Go'),
  _KnownLanguage(CodeLanguages.sql, 'SQL'),
  _KnownLanguage(CodeLanguages.json, 'JSON'),
  _KnownLanguage(CodeLanguages.yaml, 'YAML'),
  _KnownLanguage(CodeLanguages.toml, 'TOML'),
  _KnownLanguage(CodeLanguages.xml, 'XML'),
  _KnownLanguage(CodeLanguages.graphql, 'GraphQL'),
  _KnownLanguage(CodeLanguages.shellscript, 'Bash', [
    'bash',
    'shell',
    'shellscript',
  ]),
  _KnownLanguage(CodeLanguages.powershell, 'PowerShell'),
  _KnownLanguage(CodeLanguages.docker, 'Dockerfile', ['dockerfile']),
  _KnownLanguage(CodeLanguages.diff, 'Diff', ['patch']),
  _KnownLanguage(CodeLanguages.markdown, 'Markdown'),
];

String? _languageName(String? value) => _firstWord(value)?.toLowerCase();

String? _firstWord(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) return null;
  return trimmed.split(RegExp(r'\s+')).first;
}
