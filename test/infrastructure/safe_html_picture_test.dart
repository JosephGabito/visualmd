import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/domain/reading/content/inline.dart';
import 'package:visualmd/infrastructure/markdown/safe_html_picture.dart';

void main() {
  test('similarly prefixed custom elements are not pictures', () {
    for (final source in [
      '<picture-frame>Readable text</picture-frame>',
      '<picture:frame>Readable text</picture:frame>',
      '<picture.frame>Readable text</picture.frame>',
    ]) {
      expect(SafeHtmlPicture.claims(source), isFalse, reason: source);
      expect(SafeHtmlPicture.parse(source), isNull, reason: source);
    }
  });

  test('GitHub theme candidates become ordered domain image sources', () {
    final image = SafeHtmlPicture.parse('''
<picture data-private="gone">
  <source media="(prefers-color-scheme: dark)" srcset="dark.png">
  <source media="( prefers-color-scheme : LIGHT )" srcset="light.png">
  <img src="fallback.png" alt="A themed diagram" title="Figure &amp; one">
</picture>
''');

    expect(image, isNotNull);
    expect(image!.source, 'fallback.png');
    expect(image.alt, 'A themed diagram');
    expect(image.title, 'Figure & one');
    expect(image.themedSources.map((candidate) => candidate.scheme), [
      ImageColorScheme.dark,
      ImageColorScheme.light,
    ]);
    expect(image.themedSources.map((candidate) => candidate.source), [
      'dark.png',
      'light.png',
    ]);
  });

  test('unsupported source selection falls through to the required image', () {
    final image = SafeHtmlPicture.parse('''
<picture>
  <source media="(min-width: 60em)" srcset="wide.png">
  <source media="(prefers-color-scheme: dark)"
          srcset="dark.png, dark@2x.png 2x">
  <source media="(prefers-color-scheme: dark)" type="image/avif"
          srcset="dark.avif">
  <img src="fallback.png" alt="Fallback diagram">
</picture>
''');

    expect(image, isNotNull);
    expect(image!.themedSources, isEmpty);
    expect(image.sourceFor(ImageColorScheme.dark), 'fallback.png');
  });

  test('incomplete or inaccessible pictures do not become images', () {
    for (final source in [
      '<picture/>',
      '</picture>',
      '<picture><img src="fallback.png" alt="Fallback">',
      '<picture><source media="(prefers-color-scheme: dark)" '
          'srcset="dark.png"></picture>',
      '<picture><img src="fallback.png"></picture>',
      '<picture><img src="one.png" alt="One"><img src="two.png" '
          'alt="Two"></picture>',
      '<picture><script>never()</script><img src="safe.png" '
          'alt="Safe"></picture>',
      '<picture>visible text<img src="safe.png" alt="Safe"></picture>',
    ]) {
      expect(SafeHtmlPicture.claims(source), isTrue);
      expect(SafeHtmlPicture.parse(source), isNull, reason: source);
    }
  });
}
