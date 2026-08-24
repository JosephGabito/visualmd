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
    expect(
      ReadingDirection.of('👩🏽‍💻 123 — العربية', fallback: TextDirection.ltr),
      TextDirection.rtl,
    );
    expect(
      ReadingDirection.of('1️⃣ (עברית)', fallback: TextDirection.ltr),
      TextDirection.rtl,
    );
    expect(
      ReadingDirection.of(
        '\u2067English inside an isolate\u2069 العربية',
        fallback: TextDirection.ltr,
      ),
      TextDirection.rtl,
    );
    expect(
      ReadingDirection.of(
        '${String.fromCharCode(0x1e900)} after emoji 👩🏽‍💻',
        fallback: TextDirection.ltr,
      ),
      TextDirection.rtl,
      reason: 'astral right-to-left scripts must not be read as surrogates',
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
