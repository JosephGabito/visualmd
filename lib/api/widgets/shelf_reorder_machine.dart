part of 'shelf_panel.dart';

sealed class _ShelfReorderState {
  const _ShelfReorderState();
}

final class _ShelfReorderIdle extends _ShelfReorderState {
  const _ShelfReorderIdle();
}

final class _ShelfReorderDragging extends _ShelfReorderState {
  final LibraryRootId source;
  final int sourceIndex;
  final int? insertionIndex;

  const _ShelfReorderDragging({
    required this.source,
    required this.sourceIndex,
    required this.insertionIndex,
  });

  _ShelfReorderDragging target(int? index) => _ShelfReorderDragging(
    source: source,
    sourceIndex: sourceIndex,
    insertionIndex: index,
  );
}

final class _ShelfReorderSettling extends _ShelfReorderState {
  final LibraryRootId source;

  const _ShelfReorderSettling(this.source);
}

final class _ShelfReorderDrop {
  final LibraryRootId source;
  final int sourceIndex;
  final int? insertionIndex;

  const _ShelfReorderDrop({
    required this.source,
    required this.sourceIndex,
    required this.insertionIndex,
  });

  bool get moved => insertionIndex != null && insertionIndex != sourceIndex;
}

final class _ShelfReorderMachine {
  _ShelfReorderState _state = const _ShelfReorderIdle();

  _ShelfReorderDragging? get dragging => switch (_state) {
    final _ShelfReorderDragging dragging => dragging,
    _ => null,
  };

  bool get blocksRootInteractions => _state is! _ShelfReorderIdle;

  bool start(LibraryRootId source, int sourceIndex) {
    if (_state is! _ShelfReorderIdle) return false;
    _state = _ShelfReorderDragging(
      source: source,
      sourceIndex: sourceIndex,
      insertionIndex: sourceIndex,
    );
    return true;
  }

  bool target(int? insertionIndex) {
    final dragging = this.dragging;
    if (dragging == null || dragging.insertionIndex == insertionIndex) {
      return false;
    }
    _state = dragging.target(insertionIndex);
    return true;
  }

  _ShelfReorderDrop? drop() {
    final dragging = this.dragging;
    if (dragging == null) return null;
    _state = _ShelfReorderSettling(dragging.source);
    return _ShelfReorderDrop(
      source: dragging.source,
      sourceIndex: dragging.sourceIndex,
      insertionIndex: dragging.insertionIndex,
    );
  }

  bool settle() {
    if (_state is! _ShelfReorderSettling) return false;
    _state = const _ShelfReorderIdle();
    return true;
  }

  bool retain(Set<LibraryRootId> live) {
    final source = switch (_state) {
      final _ShelfReorderDragging dragging => dragging.source,
      final _ShelfReorderSettling settling => settling.source,
      _ => null,
    };
    if (source == null || live.contains(source)) return false;
    _state = const _ShelfReorderIdle();
    return true;
  }
}
