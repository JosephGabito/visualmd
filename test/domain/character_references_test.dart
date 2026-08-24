import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/domain/reading/character_references.dart';
import 'package:visualmd/domain/reading/named_character_references.g.dart';

void main() {
  group('CharacterReferences', () {
    test('resolves named references from the complete WHATWG table', () {
      expect(namedCharacterReferences, hasLength(2125));
      expect(
        CharacterReferences.decode(
          '&nbsp; &amp; &copy; &AElig; &Dcaron; &frac34; &HilbertSpace; '
          '&DifferentialD; &ClockwiseContourIntegral; &ngE;',
        ),
        '\u00a0 & © Æ Ď ¾ ℋ ⅆ ∲ ≧̸',
      );
    });

    test('resolves bounded decimal and hexadecimal references', () {
      expect(
        CharacterReferences.decode(
          '&#35; &#1234; &#992; &#0; &#X22; &#XD06; &#xcab;',
        ),
        '# Ӓ Ϡ � " ആ ಫ',
      );
      expect(
        CharacterReferences.decode('&#55296; &#xD800; &#1114112;'),
        '� � �',
      );
      expect(CharacterReferences.decode('&#1; &#x1;'), '� \u0001');
    });

    test('leaves malformed, unknown, and unterminated forms authored', () {
      const source =
          '&nbsp &x; &#; &#x; &#87654321; &#abcdef0; '
          '&ThisIsNotDefined; &hi?; &copy';

      expect(CharacterReferences.decode(source), source);
    });

    test(
      'names remain case-sensitive while the hexadecimal marker does not',
      () {
        expect(CharacterReferences.decode('&AMP; &amp; &Amp;'), '& & &Amp;');
        expect(CharacterReferences.decode('&#x41; &#X41;'), 'A A');
      },
    );
  });
}
