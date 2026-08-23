import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/infrastructure/folder_registry.dart';
import 'package:visualmd/infrastructure/markdown_registry.dart';

void main() {
  test(
    'stable identities refresh one handle while anonymous handles append',
    () {
      final registry = FolderRegistry<String>('folder');
      final first = registry.register('docs', 'old', identity: '/work/docs');
      final refreshed = registry.register(
        'docs',
        'new',
        identity: '/work/docs',
      );
      final anonymous = registry.register('docs', 'other');

      expect(refreshed, first);
      expect(registry.lookup(first), 'new');
      expect(anonymous, isNot(first));
    },
  );

  test('restoration honors a workspace source identity over an old handle', () {
    final registry = FolderRegistry<String>('folder');
    registry.register('docs', 'temporary', identity: '/work/docs');

    final restored = registry.register(
      'docs',
      'restored',
      identity: '/work/docs',
      preferredId: 'stable-source',
    );

    expect(restored.id, 'stable-source');
    expect(registry.lookup(restored), 'restored');
  });

  test('standalone restoration honors its workspace source identity', () {
    final registry = MarkdownRegistry<String>('markdown');
    registry.register('plan.md', 'temporary', identity: '/work/plan.md');

    final restored = registry.register(
      'plan.md',
      'restored',
      identity: '/work/plan.md',
      preferredId: 'stable-source',
    );

    expect(restored.id, 'stable-source');
    expect(registry.lookup(restored), 'restored');
  });

  test('fresh registries cannot issue the same durable source identity', () {
    final first = FolderRegistry<String>('folder').register('one', 'one');
    final second = FolderRegistry<String>('folder').register('two', 'two');

    expect(first.id, isNot(second.id));
  });

  test('a reused legacy workspace id cannot alias its previous path', () {
    final registry = FolderRegistry<String>('folder');
    registry.register('old', 'old', identity: '/old', preferredId: 'legacy-0');
    registry.register('new', 'new', identity: '/new', preferredId: 'legacy-0');

    final offeredAgain = registry.register(
      'old',
      'old-again',
      identity: '/old',
    );

    expect(offeredAgain.id, isNot('legacy-0'));
    expect(registry.lookup(offeredAgain), 'old-again');
  });
}
