import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/domain/collection/persistent_sequence.dart';

void main() {
  test('suffix replacement preserves the prior immutable snapshot', () {
    final original = PersistentSequence<int>.from(
      List.generate(1000, (index) => index),
    );
    final next = original.replace(
      index: 999,
      removeCount: 1,
      values: const [1000, 1001],
    );

    expect(original.length, 1000);
    expect(original.last, 999);
    expect(next.length, 1001);
    expect(next[998], 998);
    expect(next.skip(999), [1000, 1001]);
  });

  test('public mutation APIs cannot alter a sequence', () {
    final sequence = PersistentSequence<int>.from(const [1, 2, 3]);

    expect(() => sequence[0] = 9, throwsUnsupportedError);
    expect(() => sequence.length = 0, throwsUnsupportedError);
    expect(() => sequence.add(4), throwsUnsupportedError);
  });

  test('invalid replacement ranges fail before creating a snapshot', () {
    final sequence = PersistentSequence<int>.from(const [1, 2, 3]);

    expect(
      () => sequence.replace(index: 2, removeCount: 2, values: const []),
      throwsRangeError,
    );
  });
}
