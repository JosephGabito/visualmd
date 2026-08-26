import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/infrastructure/markdown/safe_html_text.dart';

void main() {
  test('safe containers contribute words but never attributes', () {
    final text = SafeHtmlText.block('''
<div onclick="steal()">
  Read <strong data-secret="hidden">these words</strong> safely.
</div>
''');

    expect(text, 'Read these words safely.');
    expect(text, isNot(contains('onclick')));
    expect(text, isNot(contains('data-secret')));
  });

  test('HTML-looking attribute values never become reading content', () {
    expect(
      SafeHtmlText.block(
        '<div data-example="<script>*not content*</script>">Safe.</div>',
      ),
      'Safe.',
    );
  });

  test('tag removal neither invents nor erases punctuation spacing', () {
    expect(
      SafeHtmlText.block(
        '<p>Before <strong>marked words</strong>, then <em>another</em>.</p>',
      ),
      'Before marked words, then another.',
    );
  });

  test(
    'block boundaries survive source wrapping without blank-line inflation',
    () {
      expect(
        SafeHtmlText.block('''
<section>
  A sentence wrapped in the source
  remains one reading sentence.
  <p>A distinct paragraph remains distinct.</p>
</section>
'''),
        'A sentence wrapped in the source remains one reading sentence.\n'
        'A distinct paragraph remains distinct.',
      );
    },
  );

  test('comments carry no reading content', () {
    expect(
      SafeHtmlText.inline('<!-- private note -->'),
      isA<HiddenInlineHtml>(),
    );
    expect(SafeHtmlText.block('<!-- private\nnote -->'), isNull);
  });

  test('dangerous elements remain visible inert source', () {
    const source = '<script>alert("never run");</script>';

    expect(SafeHtmlText.block(source), source);
    expect(
      SafeHtmlText.inline('<script>'),
      isA<VisibleInlineHtml>().having(
        (value) => value.source,
        'source',
        '<script>',
      ),
    );
    expect(SafeHtmlText.inline('</script>'), isA<VisibleInlineHtml>());
  });

  test('processing instructions and declarations remain authored source', () {
    for (final source in [
      '<?php echo "safe"; ?>',
      '<!DOCTYPE html>',
      '<![CDATA[<raw>content</raw>]]>',
    ]) {
      expect(SafeHtmlText.inline(source), isA<VisibleInlineHtml>());
      expect(SafeHtmlText.block(source), source);
    }
  });

  test('adjacent raw forms keep independent safety policies', () {
    expect(
      SafeHtmlText.block('''
<!-- hidden -->
<?php echo "visible"; ?>
'''),
      '<?php echo "visible"; ?>',
    );
    expect(
      SafeHtmlText.block('''
<div data-secret="gone">Safe words.</div>
<script>*exact source*</script>
'''),
      'Safe words.\n<script>*exact source*</script>',
    );
  });

  test('safe reduction cannot synthesize a protected-source identity', () {
    expect(
      SafeHtmlText.block('''
<div>VISUALMDOPAQUE<span></span>0TOKEN</div>
<div>VISUALMDOPAQUE&#48;TOKEN</div>
<script>alert(1)</script>
'''),
      'VISUALMDOPAQUE0TOKEN\n'
      'VISUALMDOPAQUE0TOKEN\n'
      '<script>alert(1)</script>',
    );
  });

  test(
    'protected source survives restrictive HTML insertion modes in order',
    () {
      expect(
        SafeHtmlText.block('''
<select>
  <option>Before</option>
  <script>inside select</script>
  <option>After</option>
</select>
'''),
        'Before\n<script>inside select</script>\nAfter',
      );
      expect(
        SafeHtmlText.block('''
<table>
  <script>inside table</script>
  <tbody><tr><td>After</td></tr></tbody>
</table>
'''),
        '<script>inside table</script>\nAfter',
      );
    },
  );

  test('current CommonMark containers preserve reading boundaries', () {
    expect(
      SafeHtmlText.block('<details><summary>Title</summary>Body</details>'),
      'Title\nBody',
    );
    expect(
      SafeHtmlText.block('<center>One</center><center>Two</center>'),
      'One\nTwo',
    );
  });

  test('HTML5 recovery keeps readable words from malformed safe markup', () {
    expect(SafeHtmlText.block('<div><strong>unfinished'), 'unfinished');
  });

  test('inline structural tags separate adjacent words', () {
    expect(SafeHtmlText.inline('<br>'), isA<BreakInlineHtml>());
    expect(SafeHtmlText.inline('<div>'), isA<BreakInlineHtml>());
    expect(SafeHtmlText.inline('<span>'), isA<HiddenInlineHtml>());
  });
}
