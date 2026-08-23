import 'package:flutter/material.dart';

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

  /// Held raised while something the control opened is still on screen.
  final bool active;

  final String? tooltip;
  final Widget child;

  const Pressable({
    super.key,
    required this.onPress,
    required this.child,
    this.active = false,
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

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPress != null;
    final still = MediaQuery.disableAnimationsOf(context);

    final control = MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: enabled
            ? (_) {
                setState(() => _pressed = true);
                widget.onPress!();
              }
            : null,
        onPointerUp: (_) => setState(() => _pressed = false),
        onPointerCancel: (_) => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: !enabled
              ? 1
              : _pressed
              ? _pressScale
              : (_hovered || widget.active ? _hoverScale : 1),
          duration: still ? Duration.zero : const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: Opacity(opacity: enabled ? 1 : 0.4, child: widget.child),
        ),
      ),
    );

    return widget.tooltip == null
        ? control
        : Tooltip(message: widget.tooltip!, child: control);
  }
}
