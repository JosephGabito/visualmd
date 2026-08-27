import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A control that acts the moment the pointer goes down.
///
/// Waiting for the release puts the interface a beat behind the hand, and a
/// raw [Listener] rather than a tap gesture keeps it that way even inside the
/// window-drag handler that wraps the top bar on macOS: pointer events are not
/// subject to the gesture arena, so nothing can defer the callback.
///
/// The control leans in under the pointer and gives under the press, so it has
/// answered before it acts.
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
    this.tooltip,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  static const _hoverScale = 1.06;
  static const _pressScale = 0.94;

  var _hovered = false;
  var _pressed = false;
  var _focused = false;

  void _activate() => widget.onPress?.call();

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPress != null;
    final still = MediaQuery.disableAnimationsOf(context);

    final duration = still ? Duration.zero : const Duration(milliseconds: 120);
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
        onFocusChange: (focused) => setState(() => _focused = focused),
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
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: enabled
                ? (_) {
                    setState(() => _pressed = true);
                    _activate();
                  }
                : null,
            onPointerUp: (_) => setState(() => _pressed = false),
            onPointerCancel: (_) => setState(() => _pressed = false),
            child: AnimatedContainer(
              duration: duration,
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _focused
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(7),
              ),
              child: AnimatedScale(
                scale: !enabled
                    ? 1
                    : _pressed
                    ? _pressScale
                    : (_hovered || widget.active ? _hoverScale : 1),
                duration: duration,
                curve: Curves.easeOut,
                child: Opacity(opacity: enabled ? 1 : 0.4, child: widget.child),
              ),
            ),
          ),
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
