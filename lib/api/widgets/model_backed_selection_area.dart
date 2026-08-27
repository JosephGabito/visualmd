import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// Extends Flutter selection with a lazy, model-owned whole-document snapshot.
///
/// A lazy viewport cannot register unmounted text with [SelectionArea]. Select
/// All therefore records the complete reading text from the model, then still
/// forwards the intent so mounted text receives native visual selection. Copy
/// uses that stable snapshot; ordinary pointer selections remain Flutter-owned.
final class ModelBackedSelectionArea extends StatefulWidget {
  final String Function() wholeText;
  final Widget child;

  const ModelBackedSelectionArea({
    super.key,
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
    _copyWholeDocument,
  );
  String? _wholeDocumentSelection;
  var _forwardingSelectAll = false;

  void _rememberWholeDocument() {
    _wholeDocumentSelection = widget.wholeText();
    _forwardingSelectAll = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _forwardingSelectAll = false;
    });
  }

  bool _copyWholeDocument() {
    final selected = _wholeDocumentSelection;
    if (selected == null) return false;
    unawaited(Clipboard.setData(ClipboardData(text: selected)));
    return true;
  }

  void _nativeSelectionChanged(SelectedContent? selection) {
    if (_forwardingSelectAll || _wholeDocumentSelection == null) return;
    _wholeDocumentSelection = null;
  }

  @override
  Widget build(BuildContext context) => Actions(
    actions: <Type, Action<Intent>>{
      SelectAllTextIntent: _selectAll,
      CopySelectionTextIntent: _copy,
    },
    child: SelectionArea(
      onSelectionChanged: _nativeSelectionChanged,
      child: widget.child,
    ),
  );
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
