import 'package:flutter/material.dart';

/// Which edge a panel is anchored to, and therefore which way it leaves.
enum PanelSide { left, right }

/// A side panel that slides out of the way instead of vanishing.
///
/// The panel keeps its full width throughout and is clipped as it goes, so its
/// contents never reflow mid-flight — only the space it occupies changes, and
/// the page takes up the difference. It is short (180 ms) and decelerating:
/// long enough to follow with the eye, short enough not to wait for.
class CollapsiblePanel extends StatelessWidget {
  final bool visible;
  final double width;
  final PanelSide side;
  final Widget child;

  const CollapsiblePanel({
    super.key,
    required this.visible,
    required this.width,
    required this.side,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);

    return TweenAnimationBuilder<double>(
      tween: Tween(end: visible ? 1 : 0),
      duration: still ? Duration.zero : const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) {
        if (t == 0) return const SizedBox.shrink();
        return ClipRect(
          child: Align(
            // Pinned to the edge it lives against, so the far side is what
            // gets clipped: the panel reads as sliding out, not as squashing.
            alignment: side == PanelSide.left
                ? Alignment.centerRight
                : Alignment.centerLeft,
            widthFactor: t,
            child: Opacity(
              // Fades a little late, so it is on its way out before it dims.
              opacity: Curves.easeOut.transform(t.clamp(0.0, 1.0)),
              child: SizedBox(width: width, child: child),
            ),
          ),
        );
      },
      child: child,
    );
  }
}
