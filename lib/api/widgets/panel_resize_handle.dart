import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

import '../theme/library_theme.dart';
import 'collapsible_panel.dart';

/// The quiet, accessible seam by which a side panel changes width.
///
/// Arrow keys move the seam in the same direction they would move a pointer;
/// double-click returns it to the width the room was designed around.
class PanelResizeHandle extends StatefulWidget {
  static const double extent = 7;
  static const double keyboardStep = 16;

  final String panelName;
  final PanelSide side;
  final double width;
  final ValueChanged<double> onResizeBy;
  final VoidCallback onCommit;
  final VoidCallback onReset;

  const PanelResizeHandle({
    super.key,
    required this.panelName,
    required this.side,
    required this.width,
    required this.onResizeBy,
    required this.onCommit,
    required this.onReset,
  });

  @override
  State<PanelResizeHandle> createState() => _PanelResizeHandleState();
}

class _PanelResizeHandleState extends State<PanelResizeHandle> {
  final _focus = FocusNode();
  bool _hovering = false;
  bool _focused = false;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _moveSeam(double physicalDelta, {bool commit = false}) {
    widget.onResizeBy(
      widget.side == PanelSide.left ? physicalDelta : -physicalDelta,
    );
    if (commit) widget.onCommit();
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _moveSeam(-PanelResizeHandle.keyboardStep, commit: true);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _moveSeam(PanelResizeHandle.keyboardStep, commit: true);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.home) {
      widget.onReset();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final chrome = context.chrome;
    final active = _hovering || _focused;
    return Semantics(
      label: 'Resize ${widget.panelName}',
      value: '${widget.width.round()} pixels',
      increasedValue:
          '${(widget.width + PanelResizeHandle.keyboardStep).round()} pixels',
      decreasedValue:
          '${(widget.width - PanelResizeHandle.keyboardStep).round()} pixels',
      onIncrease: () {
        widget.onResizeBy(PanelResizeHandle.keyboardStep);
        widget.onCommit();
      },
      onDecrease: () {
        widget.onResizeBy(-PanelResizeHandle.keyboardStep);
        widget.onCommit();
      },
      child: Focus(
        focusNode: _focus,
        onFocusChange: (focused) => setState(() => _focused = focused),
        onKeyEvent: _onKeyEvent,
        child: MouseRegion(
          cursor: SystemMouseCursors.resizeColumn,
          onEnter: (_) => setState(() => _hovering = true),
          onExit: (_) => setState(() => _hovering = false),
          child: Listener(
            // Focus belongs to the seam from pointer-down, independently of
            // which recognizer later wins the drag/double-click arena.
            onPointerDown: (_) => _focus.requestFocus(),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              dragStartBehavior: DragStartBehavior.down,
              onHorizontalDragUpdate: (details) => _moveSeam(details.delta.dx),
              onHorizontalDragEnd: (_) => widget.onCommit(),
              onDoubleTap: widget.onReset,
              child: SizedBox(
                width: PanelResizeHandle.extent,
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    width: active ? 2 : 1,
                    color: active ? p.accent : chrome.separator,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
