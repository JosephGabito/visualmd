import '../application/ports/folder_scanner.dart';
import 'opaque_ids.dart';

/// Issues opaque [FolderRef]s for platform handles (browser entries, local
/// paths…) so the application can refer to folders without knowing what a
/// platform is. Each adapter family keeps its own registry.
final class FolderRegistry<T extends Object> {
  final String _prefix;
  final _handles = <String, T>{};
  final _idsByIdentity = <String, String>{};

  FolderRegistry(this._prefix);

  FolderRef register(
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
      return FolderRef(id: preferredId, name: name);
    }
    final existing = identity == null ? null : _idsByIdentity[identity];
    if (existing != null) {
      _handles[existing] = handle;
      return FolderRef(id: existing, name: name);
    }
    final id = _nextAvailableId();
    _handles[id] = handle;
    if (identity != null) _idsByIdentity[identity] = id;
    return FolderRef(id: id, name: name);
  }

  String _nextAvailableId() {
    while (true) {
      final candidate = OpaqueIds.next(_prefix);
      if (!_handles.containsKey(candidate)) return candidate;
    }
  }

  T? lookup(FolderRef ref) => _handles[ref.id];
}
