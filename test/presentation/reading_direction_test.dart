import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/api/render/reading_direction.dart';

void main() {
  test('the first strong character establishes reading direction', () {
    expect(
      ReadingDirection.of('العربية then English', fallback: TextDirection.ltr),
      TextDirection.rtl,
    );
    expect(
      ReadingDirection.of('English ثم العربية', fallback: TextDirection.rtl),
      TextDirection.ltr,
    );
    expect(
      ReadingDirection.of('... עברית', fallback: TextDirection.ltr),
      TextDirection.rtl,
    );
    expect(
      ReadingDirection.of('日本語と中文', fallback: TextDirection.rtl),
      TextDirection.ltr,
    );
  });

  test('directionally neutral headings inherit their reading context', () {
    expect(
      ReadingDirection.of('!!! ——— …', fallback: TextDirection.rtl),
      TextDirection.rtl,
    );
    expect(
      ReadingDirection.of('', fallback: TextDirection.ltr),
      TextDirection.ltr,
    );
  });
}
