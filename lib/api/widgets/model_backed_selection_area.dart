import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// Maps one displayed text boundary back to its authored source boundary.
typedef SourceOffsetAt = int Function(int displayOffset);

/// Extends Flutter selection with model-owned text for unmounted blocks.
///
/// A lazy viewport cannot register unmounted text with [SelectionArea]. Select
/// All therefore records the complete reading text from the model, then still
/// forwards the intent so mounted text receives native visual selection. Copy
/// uses that stable snapshot. Ordinary pointer selection keeps Flutter's
/// gesture and highlight, while [ModelSelectionBlock] records each local range
/// before its lazy widget leaves the viewport.
final class ModelBackedSelectionArea extends StatefulWidget {
  final Object selectionIdentity;
  final String Function() wholeText;
  final Widget child;

  const ModelBackedSelectionArea({
    super.key,
    required this.selectionIdentity,
    required this.wholeText,
    required this.child,
  });

  @override
  State<ModelBackedSelectionArea> createState() =>
      _ModelBackedSelectionAreaState();
}

final class _ModelBackedSelectionAreaState
    extends State<ModelBackedSelectionArea> {
  late final _SelectAllDocumentAction _selectAll = _SelectAllDocumentAction(
    _rememberWholeDocument,
  );
  late final _CopyDocumentSelectionAction _copy = _CopyDocumentSelectionAction(
    _copyModelSelection,
  );
  final _modelSelection = ModelSelectionSnapshot();
  String? _wholeDocumentSelection;
  var _forwardingSelectAll = false;

  void _rememberWholeDocument() {
    _modelSelection
      ..clear()
      ..suspended = true;
    _wholeDocumentSelection = widget.wholeText();
    _forwardingSelectAll = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _forwardingSelectAll = false;
      _modelSelection.suspended = false;
    });
  }

  bool _copyModelSelection() {
    final selected = _wholeDocumentSelection ?? _modelSelection.selectedText;
    if (selected == null || selected.isEmpty) return false;
    unawaited(Clipboard.setData(ClipboardData(text: selected)));
    return true;
  }

  void _nativeSelectionChanged(SelectedContent? selection) {
    if (_forwardingSelectAll) return;
    _wholeDocumentSelection = null;
    if (selection == null) _modelSelection.clear();
  }

  void _beginPointerSelection(PointerDownEvent event) {
    if (event.buttons & kPrimaryButton == 0) return;
    _wholeDocumentSelection = null;
    _modelSelection.clear();
  }

  @override
  void didUpdateWidget(ModelBackedSelectionArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectionIdentity != widget.selectionIdentity) {
      _wholeDocumentSelection = null;
      _modelSelection.clear();
    }
  }

  @override
  Widget build(BuildContext context) => Actions(
    actions: <Type, Action<Intent>>{
      SelectAllTextIntent: _selectAll,
      CopySelectionTextIntent: _copy,
    },
    child: _ModelSelectionScope(
      snapshot: _modelSelection,
      child: Listener(
        onPointerDown: _beginPointerSelection,
        child: SelectionArea(
          onSelectionChanged: _nativeSelectionChanged,
          child: widget.child,
        ),
      ),
    ),
  );
}

/// The selected source ranges which survive lazy widget disposal.
///
/// The snapshot is deliberately not a notifier. Selection painting remains
/// Flutter-owned, and copying reads this object only when the command arrives.
/// A drag therefore cannot rebuild the document on every pointer update.
final class ModelSelectionSnapshot {
  final _ranges = <Object, _ModelSelectionRange>{};
  bool suspended = false;

  void update({
    required Object identity,
    required int order,
    required String text,
    int rangeOffset = 0,
    SourceOffsetAt? sourceOffsetAt,
    required SelectedContentRange? range,
    required SelectionStatus status,
  }) {
    if (suspended) return;
    if (range == null || status != SelectionStatus.uncollapsed) {
      _ranges.remove(identity);
      return;
    }
    final start =
        (sourceOffsetAt?.call(range.startOffset) ??
                range.startOffset + rangeOffset)
            .clamp(0, text.length)
            .toInt();
    final end =
        (sourceOffsetAt?.call(range.endOffset) ?? range.endOffset + rangeOffset)
            .clamp(0, text.length)
            .toInt();
    if (start == end) {
      _ranges.remove(identity);
      return;
    }
    _ranges[identity] = _ModelSelectionRange(
      order: order,
      text: text,
      start: start < end ? start : end,
      end: start < end ? end : start,
    );
  }

  void clear() => _ranges.clear();

  String? get selectedText {
    if (_ranges.isEmpty) return null;
    final ranges = _ranges.values.toList(growable: false)
      ..sort((left, right) => left.order.compareTo(right.order));
    return ranges
        .map((range) => range.text.substring(range.start, range.end))
        .join('\n\n');
  }
}

final class _ModelSelectionRange {
  final int order;
  final String text;
  final int start;
  final int end;

  const _ModelSelectionRange({
    required this.order,
    required this.text,
    required this.start,
    required this.end,
  });
}

/// Captures the local source range beneath one lazy document block.
///
/// Disposal intentionally leaves the last range in the shared snapshot. The
/// widget is expendable; the selected document range is not.
final class ModelSelectionBlock extends StatefulWidget {
  final Object identity;
  final int order;
  final String text;
  final int rangeOffset;
  final SourceOffsetAt? sourceOffsetAt;
  final Widget child;

  const ModelSelectionBlock({
    super.key,
    required this.identity,
    required this.order,
    required this.text,
    this.rangeOffset = 0,
    this.sourceOffsetAt,
    required this.child,
  }) : assert(rangeOffset >= 0);

  @override
  State<ModelSelectionBlock> createState() => _ModelSelectionBlockState();
}

final class _ModelSelectionBlockState extends State<ModelSelectionBlock> {
  final _notifier = SelectionListenerNotifier();
  ModelSelectionSnapshot? _snapshot;

  @override
  void initState() {
    super.initState();
    _notifier.addListener(_recordSelection);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _snapshot = _ModelSelectionScope.of(context);
  }

  @override
  void didUpdateWidget(ModelSelectionBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.identity != widget.identity) {
      _snapshot?.update(
        identity: oldWidget.identity,
        order: oldWidget.order,
        text: oldWidget.text,
        range: null,
        status: SelectionStatus.none,
      );
    }
    _recordSelection();
  }

  void _recordSelection() {
    if (!_notifier.registered) return;
    final selection = _notifier.selection;
    _snapshot?.update(
      identity: widget.identity,
      order: widget.order,
      text: widget.text,
      rangeOffset: widget.rangeOffset,
      sourceOffsetAt: widget.sourceOffsetAt,
      range: selection.range,
      status: selection.status,
    );
  }

  @override
  void dispose() {
    _notifier
      ..removeListener(_recordSelection)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      SelectionListener(selectionNotifier: _notifier, child: widget.child);
}

final class _ModelSelectionScope extends InheritedWidget {
  final ModelSelectionSnapshot snapshot;

  const _ModelSelectionScope({required this.snapshot, required super.child});

  static ModelSelectionSnapshot? of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_ModelSelectionScope>()
      ?.snapshot;

  @override
  bool updateShouldNotify(_ModelSelectionScope oldWidget) =>
      !identical(snapshot, oldWidget.snapshot);
}

final class _SelectAllDocumentAction extends Action<SelectAllTextIntent> {
  final VoidCallback beforeNativeSelection;

  _SelectAllDocumentAction(this.beforeNativeSelection);

  @override
  Object? invoke(SelectAllTextIntent intent) {
    beforeNativeSelection();
    return callingAction?.invoke(intent);
  }
}

final class _CopyDocumentSelectionAction
    extends Action<CopySelectionTextIntent> {
  final bool Function() copyModelSelection;

  _CopyDocumentSelectionAction(this.copyModelSelection);

  @override
  Object? invoke(CopySelectionTextIntent intent) {
    if (!intent.collapseSelection && copyModelSelection()) return null;
    return callingAction?.invoke(intent);
  }
}
