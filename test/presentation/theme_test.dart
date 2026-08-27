import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/api/theme/library_theme.dart';
import 'package:visualmd/api/theme/library_chrome.dart';
import 'package:visualmd/presentation/theme/built_in_themes.dart';
import 'package:visualmd/presentation/theme/reader_theme.dart';
import 'package:visualmd/presentation/theme/theme_format_exception.dart';
import 'package:visualmd/presentation/theme/theme_palette.dart';
import 'package:visualmd/presentation/theme/theme_typefaces.dart';
import 'package:visualmd/presentation/theme/theme_choice.dart';
import 'package:visualmd/presentation/theme/theme_registry.dart';

const minimal = '''
{
  "id": "sepia",
  "name": "Sepia",
  "brightness": "light",
  "palette": {
    "paper": "#f4ecd8", "panel": "#ece3cc", "border": "#d8ccb0",
    "ink": "#3b2f2f", "muted": "#7a6a5a", "accent": "#8b4513",
    "codeBackground": "#ebe2c9"
  }
}
''';

void main() {
  group('ReaderTheme.fromJson', () {
    test('parses a minimal document and derives the soft tokens', () {
      final theme = ReaderTheme.fromJson(
        jsonDecode(minimal) as Map<String, Object?>,
        origin: 'sepia.json',
      );
      expect(theme.id, 'sepia');
      expect(theme.brightness, Brightness.light);
      expect(theme.origin, 'sepia.json');
      expect(theme.palette.paper, const Color(0xFFF4ECD8));
      expect(
        theme.palette.accentSoft,
        ThemePalette.deriveAccentSoft(
          const Color(0xFF8B4513),
          const Color(0xFFF4ECD8),
        ),
      );
      expect(theme.palette.selection.a, closeTo(0.3, 0.01));
      expect(theme.typefaces.serif, ThemeTypefaces.library.serif);
    });

    test('accepts short hex, alpha hex and no hash; rejects garbage', () {
      expect(ThemePalette.parseHexColor('#abc'), const Color(0xFFAABBCC));
      expect(ThemePalette.parseHexColor('aabbcc80'), const Color(0x80AABBCC));
      expect(ThemePalette.parseHexColor('#12345'), isNull);
      expect(ThemePalette.parseHexColor('#gggggg'), isNull);
    });

    test('explains what is wrong, in the author\'s terms', () {
      Map<String, Object?> doc(void Function(Map<String, Object?>) mutate) {
        final m = jsonDecode(minimal) as Map<String, Object?>;
        mutate(m);
        return m;
      }

      expect(
        () => ReaderTheme.fromJson(doc((m) => m.remove('name'))),
        throwsA(
          predicate(
            (e) => e is ThemeFormatException && e.reason.contains('"name"'),
          ),
        ),
      );
      expect(
        () => ReaderTheme.fromJson(doc((m) => m['brightness'] = 'dim')),
        throwsA(
          predicate(
            (e) => e is ThemeFormatException && e.reason.contains('"dim"'),
          ),
        ),
      );
      expect(
        () => ReaderTheme.fromJson(doc((m) => m['id'] = 'My Theme')),
        throwsA(
          predicate(
            (e) => e is ThemeFormatException && e.reason.contains('lowercase'),
          ),
        ),
      );
      expect(
        () => ReaderTheme.fromJson(
          doc((m) => (m['palette'] as Map).remove('ink')),
        ),
        throwsA(
          predicate(
            (e) =>
                e is ThemeFormatException && e.reason.contains('palette."ink"'),
          ),
        ),
      );
      expect(
        () => ReaderTheme.fromJson(
          doc((m) => (m['palette'] as Map)['ink'] = 'blue'),
        ),
        throwsA(
          predicate(
            (e) => e is ThemeFormatException && e.reason.contains('not a hex'),
          ),
        ),
      );
    });

    test('every built-in round-trips through the file format', () {
      for (final theme in BuiltInThemes.all) {
        final again = ReaderTheme.fromJson(
          jsonDecode(jsonEncode(theme.toJson())) as Map<String, Object?>,
        );
        expect(again.id, theme.id);
        expect(again.brightness, theme.brightness);
        expect(again.palette.toJson(), theme.palette.toJson());
        expect(again.typefaces.toJson(), theme.typefaces.toJson());
      }
    });
  });

  group('ThemeRegistry', () {
    test('built-ins split by brightness with a default of each', () {
      final registry = ThemeRegistry();
      expect(registry.light.map((t) => t.id), contains('paper'));
      expect(registry.dark.map((t) => t.id), contains('lamplight'));
      expect(
        registry.systemPair,
        const FollowSystem(light: 'paper', dark: 'lamplight'),
      );
    });

    test('keeps good user themes, reports bad ones, lets a user theme replace a built-in', () {
      final registry = ThemeRegistry.fromDocuments([
        (origin: 'sepia.json', json: minimal),
        (origin: 'broken.json', json: '{"id": "x"'),
        (
          origin: 'wrong.json',
          json: '{"id": "x", "name": "X", "brightness": "dark", "palette": {}}',
        ),
        (
          origin: 'paper.json',
          json: minimal
              .replaceFirst('"sepia"', '"paper"')
              .replaceFirst('"Sepia"', '"My Paper"'),
        ),
      ]);
      expect(registry.byId('sepia')?.origin, 'sepia.json');
      expect(registry.byId('paper')?.name, 'My Paper');
      expect(registry.errors.map((e) => e.origin), [
        'broken.json',
        'wrong.json',
      ]);
      expect(registry.errors.first.reason, contains('JSON'));
    });

    test(
      'resolves a choice and falls back to the default of that brightness',
      () {
        final registry = ThemeRegistry();
        expect(
          registry.resolve(const FixedTheme('nord'), Brightness.light).id,
          'nord',
        );
        expect(
          registry.resolve(registry.systemPair, Brightness.dark).id,
          'lamplight',
        );
        expect(
          registry.resolve(const FixedTheme('gone'), Brightness.dark).id,
          'lamplight',
        );
        expect(
          registry
              .resolve(
                const FollowSystem(light: 'gone', dark: 'nord'),
                Brightness.light,
              )
              .id,
          'paper',
        );
      },
    );
  });

  group('Codex theme families', () {
    test(
      'ship in the same order and under the same names as the source menu',
      () {
        expect(
          BuiltInThemes.families.map((family) => family.name),
          orderedEquals([
            'Absolutely',
            'Catppuccin',
            'Codex',
            'Everforest',
            'GitHub',
            'Gruvbox',
            'Linear',
            'Notion',
            'One',
            'Proof',
            'Raycast',
            'Rose Pine',
            'Solarized',
            'Vercel',
            'VS Code Plus',
            'Xcode',
          ]),
        );
      },
    );

    test('every family member is registered with the promised brightness', () {
      final registry = ThemeRegistry();
      for (final family in BuiltInThemes.families) {
        final light = family.light;
        final dark = family.dark;
        if (light != null) {
          expect(
            registry.byId(light)?.brightness,
            Brightness.light,
            reason: '${family.name} light',
          );
        }
        if (dark != null) {
          expect(
            registry.byId(dark)?.brightness,
            Brightness.dark,
            reason: '${family.name} dark',
          );
        }
      }
    });

    test('paired families follow the system while Proof stays light', () {
      final codex = BuiltInThemes.families.singleWhere(
        (family) => family.name == 'Codex',
      );
      expect(
        codex.choiceFor(Brightness.light),
        const FollowSystem(light: 'codex-light', dark: 'codex-dark'),
      );
      expect(
        codex.selects(const FixedTheme('codex-light'), Brightness.light),
        isTrue,
        reason: 'a preference saved before families existed stays selected',
      );

      final proof = BuiltInThemes.families.singleWhere(
        (family) => family.name == 'Proof',
      );
      expect(proof.supports(Brightness.light), isTrue);
      expect(proof.supports(Brightness.dark), isFalse);
      expect(
        proof.choiceFor(Brightness.light),
        const FixedTheme('proof-light'),
      );
    });
  });

  group('built-in text contrast', () {
    test('every text token remains readable on every surface it uses', () {
      for (final theme in BuiltInThemes.all) {
        final p = theme.palette;
        final pairs = {
          'ink on paper': (p.ink, p.paper),
          'ink on panel': (p.ink, p.panel),
          'muted on paper': (p.muted, p.paper),
          'muted on panel': (p.muted, p.panel),
          'accent on paper': (p.accent, p.paper),
        };
        for (final MapEntry(key: use, value: (foreground, background))
            in pairs.entries) {
          expect(
            ThemePalette.contrastRatio(foreground, background),
            greaterThanOrEqualTo(ThemePalette.minimumTextContrast),
            reason: '${theme.name}: $use',
          );
        }
      }
    });
  });

  group('derived chrome', () {
    test(
      'every theme produces opaque states that keep selected text legible',
      () {
        for (final theme in BuiltInThemes.all) {
          final p = LibraryPalette.of(theme.palette);
          final chrome = LibraryChrome.fromMaterials(
            paper: p.paper,
            panel: p.panel,
            border: p.border,
            ink: p.ink,
            accent: p.accent,
            brightness: theme.brightness,
          );

          for (final color in [
            chrome.topBar,
            chrome.panel,
            chrome.separator,
            chrome.hover,
            chrome.pressed,
            chrome.selected,
            chrome.selectedHover,
            chrome.elevated,
          ]) {
            expect(color.a, 1, reason: '${theme.name}: $color');
          }
          expect(
            ThemePalette.contrastRatio(p.ink, chrome.selected),
            greaterThanOrEqualTo(ThemePalette.minimumTextContrast),
            reason: '${theme.name}: selected row',
          );
          expect(
            ThemePalette.contrastRatio(p.ink, chrome.selectedHover),
            greaterThanOrEqualTo(ThemePalette.minimumTextContrast),
            reason: '${theme.name}: selected row hover',
          );
        }
      },
    );
  });

  group('reading font fallback', () {
    test('every page voice names native emoji and script faces before the platform default', () {
      const typefaces = LibraryTypefaces(ThemeTypefaces.library);
      final styles = [
        typefaces.serif(color: const Color(0xFF111111)),
        typefaces.sans(color: const Color(0xFF111111)),
        typefaces.mono(color: const Color(0xFF111111)),
      ];

      for (final style in styles) {
        expect(
          style.fontFamilyFallback!.take(3),
          orderedEquals([
            'Apple Color Emoji',
            'Segoe UI Emoji',
            'Noto Color Emoji',
          ]),
        );
        expect(style.fontFamilyFallback, contains('Noto Sans Arabic'));
        expect(style.fontFamilyFallback, contains('Noto Sans Hebrew'));
        expect(style.fontFamilyFallback, contains('Noto Sans CJK SC'));
        expect(style.fontFamilyFallback, contains('Noto Sans Devanagari'));
      }
    });
  });

  group('ThemeChoice', () {
    test('round-trips and rejects malformed input', () {
      const pair = FollowSystem(light: 'paper', dark: 'nord');
      expect(ThemeChoice.fromJson(jsonDecode(jsonEncode(pair.toJson()))), pair);
      expect(
        ThemeChoice.fromJson(
          jsonDecode(jsonEncode(const FixedTheme('nord').toJson())),
        ),
        const FixedTheme('nord'),
      );
      expect(ThemeChoice.fromJson({'mode': 'fixed'}), isNull);
      expect(ThemeChoice.fromJson('nope'), isNull);
    });
  });
}
