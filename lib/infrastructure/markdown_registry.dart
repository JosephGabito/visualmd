import '../application/ports/markdown_scanner.dart';
import 'opaque_ids.dart';

/// Issues opaque application refs for platform-specific markdown handles.
final class MarkdownRegistry<T extends Object> {
  final String _prefix;
  final _handles = <String, T>{};
  final _idsByIdentity = <String, String>{};

  MarkdownRegistry(this._prefix);

  MarkdownRef register(
    String name,
    T handle, {
    String? identity,
    String? preferredId,
  }) {
    if (preferredId != null) {
      _idsByIdentity.removeWhere(
        (candidate, id) => id == preferredId && candidate != identity,
      );
      _handles[preferredId] = handle;
      if (identity != null) _idsByIdentity[identity] = preferredId;
      return MarkdownRef(id: preferredId, name: name);
    }
    final existing = identity == null ? null : _idsByIdentity[identity];
    if (existing != null) {
      _handles[existing] = handle;
      return MarkdownRef(id: existing, name: name);
    }
    final id = _nextAvailableId();
    _handles[id] = handle;
    if (identity != null) _idsByIdentity[identity] = id;
    return MarkdownRef(id: id, name: name);
  }

  String _nextAvailableId() {
    while (true) {
      final candidate = OpaqueIds.next(_prefix);
      if (!_handles.containsKey(candidate)) return candidate;
    }
  }

  T? lookup(MarkdownRef ref) => _handles[ref.id];
}
