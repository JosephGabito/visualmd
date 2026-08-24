import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/api/highlighting/shiki_code_highlighter.dart';
import 'package:visualmd/presentation/code/code_highlighter.dart';

void main() {
  final highlighter = ShikiCodeHighlighter();

  test(
    'plain and unknown fences deliberately keep the plain fallback',
    () async {
      for (final language in [
        null,
        '',
        'txt',
        'text',
        'plaintext',
        'unknown',
      ]) {
        expect(
          await highlighter.highlight(
            source: 'alpha\tbeta',
            language: language,
            scheme: CodeHighlightScheme.light,
          ),
          isNull,
          reason: '$language should not manufacture syntax',
        );
      }
      expect(highlighter.labelFor('txt'), 'Text');
      expect(highlighter.labelFor('made-up'), 'made-up');
    },
  );

  test('the common fence aliases resolve to a human language name', () {
    expect(highlighter.labelFor('py'), 'Python');
    expect(highlighter.labelFor('sh'), 'Bash');
    expect(highlighter.labelFor('shell'), 'Bash');
    expect(highlighter.labelFor('c++'), 'C++');
    expect(highlighter.labelFor('cs'), 'C#');
    expect(highlighter.labelFor('js'), 'JavaScript');
    expect(highlighter.labelFor('ts'), 'TypeScript');
    expect(highlighter.labelFor('yml'), 'YAML');
    expect(highlighter.labelFor('dockerfile'), 'Dockerfile');
  });

  test(
    'the curated language corpus produces valid semantic source ranges',
    () async {
      const samples = <String, String>{
        'html': '<main class="reader">Hello</main>',
        'css': '.reader { color: #a65a2e; }',
        'scss': r'$ink: #222; .reader { color: $ink; }',
        'javascript': 'const answer = 42;',
        'typescript': 'const answer: number = 42;',
        'jsx': 'const view = <main>Hello</main>;',
        'tsx': 'const view: JSX.Element = <main>Hello</main>;',
        'php': '<?php final class Reader {}',
        'python': 'def title(path: str) -> str:\n    return path',
        'dart': 'final class Reader { const Reader(); }',
        'swift': 'struct Reader { let title: String }',
        'kotlin': 'data class Reader(val title: String)',
        'java': 'record Reader(String title) {}',
        'csharp': 'public sealed record Reader(string Title);',
        'ruby': 'Reader = Data.define(:title)',
        'c': 'const char *title = "Visual MD";',
        'cpp': 'const std::string title{"Visual MD"};',
        'rust': 'let title: &str = "Visual MD";',
        'go': 'title := "Visual MD"',
        'sql': 'SELECT title FROM documents WHERE id = 42;',
        'json': '{"title": "Visual MD", "version": 1}',
        'yaml': 'title: Visual MD\nversion: 1',
        'toml': 'title = "Visual MD"\nversion = 1',
        'xml': '<document version="1">Visual MD</document>',
        'graphql': 'query Reader { document { title } }',
        'bash': 'set -euo pipefail\nprintf "%s\\n" "\$title"',
        'powershell': 'Get-ChildItem | Where-Object { \$_.Name -like "*.md" }',
        'dockerfile': 'FROM scratch\nCOPY build /app',
        'diff': '@@ -1 +1 @@\n-old\n+new',
        'markdown': '# Visual MD\n\nA **quiet** reader.',
      };

      for (final entry in samples.entries) {
        final result = await highlighter.highlight(
          source: entry.value,
          language: entry.key,
          scheme: CodeHighlightScheme.dark,
        );
        expect(result, isNotNull, reason: '${entry.key} should be supported');
        expect(result!.tokens, isNotEmpty, reason: entry.key);
        expect(
          result.tokens.any((token) => token.role != CodeTokenRole.plain),
          isTrue,
          reason: '${entry.key} should carry at least one syntactic role',
        );
        for (final token in result.tokens) {
          expect(token.start, inInclusiveRange(0, entry.value.length));
          expect(
            token.end,
            inInclusiveRange(token.start + 1, entry.value.length),
          );
          expect(entry.value.substring(token.start, token.end), isNotEmpty);
        }
      }
    },
  );

  test(
    'highlighting changes colour family without changing source ranges',
    () async {
      const source = 'from pathlib import Path\nroot = Path("notes")';
      final light = await highlighter.highlight(
        source: source,
        language: 'python',
        scheme: CodeHighlightScheme.light,
      );
      final dark = await highlighter.highlight(
        source: source,
        language: 'python',
        scheme: CodeHighlightScheme.dark,
      );

      expect(light, isNotNull);
      expect(dark, isNotNull);
      expect(
        light!.tokens.map((token) => (token.start, token.end, token.role)),
        dark!.tokens.map((token) => (token.start, token.end, token.role)),
      );
      expect(
        light.tokens.map((token) => token.foreground).toSet(),
        isNot(dark.tokens.map((token) => token.foreground).toSet()),
      );
    },
  );
}
