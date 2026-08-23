import 'dart:math';

/// Process-independent opaque identities for durable refs and workspaces.
abstract final class OpaqueIds {
  static final Random _random = Random.secure();

  static String next(String prefix, [Random? random]) {
    final generator = random ?? _random;
    final micros = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final entropy = List.generate(
      3,
      (_) => generator.nextInt(0x100000000).toRadixString(16).padLeft(8, '0'),
    ).join();
    return '$prefix-$micros-$entropy';
  }
}
