import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/library_chrome.dart';
import '../theme/library_theme.dart';

/// A chrome control with ordinary release-inside button behavior.
///
/// Its surface, rather than its geometry, answers hover and press. Stable icon
/// geometry keeps a compact macOS toolbar from twitching under the pointer.
class Pressable extends StatefulWidget {
  final VoidCallback? onPress;

  /// The control's accessible name, independent of its visual child or help
  /// text.
  final String semanticLabel;

  /// Held raised while something the control opened is still on screen.
  final bool active;

  /// Whether the surface controlled by this button is currently expanded.
  ///
  /// Leave null for buttons that do not disclose another surface.
  final bool? expanded;

  /// An optional caller-owned node for restoring or directing keyboard focus.
  final FocusNode? focusNode;

  /// Menus alone may opt into native-feeling pointer-down opening. Ordinary
  /// buttons retain the ability to slide away before release to cancel.
  final bool activateOnPointerDown;

  final String? tooltip;
  final Widget child;

  const Pressable({
    super.key,
    required this.onPress,
    required this.semanticLabel,
    required this.child,
    this.active = false,
    this.expanded,
    this.focusNode,
    this.activateOnPointerDown = false,
    this.tooltip,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  var _hovered = false;
  var _pressed = false;
  var _focused = false;

  void _activate() => widget.onPress?.call();

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPress != null;
    final still = MediaQuery.disableAnimationsOf(context);
    final chrome = context.chrome;

    final duration = still ? Duration.zero : const Duration(milliseconds: 120);
    final surface = AnimatedContainer(
      duration: duration,
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: !enabled
            ? Colors.transparent
            : _pressed
            ? chrome.pressed
            : (_hovered || widget.active)
            ? chrome.hover
            : Colors.transparent,
        border: Border.all(
          color: _focused ? chrome.focus : Colors.transparent,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(LibraryChromeScale.controlRadius),
      ),
      child: Opacity(opacity: enabled ? 1 : 0.38, child: widget.child),
    );
    final pointerControl = widget.activateOnPointerDown
        ? Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: enabled
                ? (_) {
                    setState(() => _pressed = true);
                    _activate();
                  }
                : null,
            onPointerUp: (_) => setState(() => _pressed = false),
            onPointerCancel: (_) => setState(() => _pressed = false),
            child: surface,
          )
        : GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
            onTapUp: enabled
                ? (_) {
                    setState(() => _pressed = false);
                    _activate();
                  }
                : null,
            onTapCancel: enabled
                ? () => setState(() => _pressed = false)
                : null,
            child: surface,
          );
    final control = Semantics(
      button: true,
      enabled: enabled,
      expanded: widget.expanded,
      label: widget.semanticLabel,
      onTap: enabled ? _activate : null,
      excludeSemantics: true,
      child: FocusableActionDetector(
        enabled: enabled,
        focusNode: widget.focusNode,
        // The first toolbar control receives programmatic focus when the
        // window opens. Paint focus only after keyboard traversal; otherwise
        // launch looks like an already-selected purple control on macOS.
        onShowFocusHighlight: (focused) => setState(() => _focused = focused),
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _activate();
              return null;
            },
          ),
        },
        child: MouseRegion(
          cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: pointerControl,
        ),
      ),
    );

    return widget.tooltip == null
        ? control
        : Tooltip(
            message: widget.tooltip!,
            excludeFromSemantics: true,
            child: control,
          );
  }
}
