import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/library_theme.dart';
import '../theme/library_chrome.dart';
import 'pressable.dart';

/// A menu that opens from the thing you clicked.
///
/// The motion follows a few well-worn principles rather than the framework
/// default, which grows a surface out of nowhere:
///
/// * **Staging / spatial continuity** — the surface scales from the trigger's
///   corner, not from its own centre, so it reads as coming *from* the button.
/// * **Slow in, slow out** — an emphasised decelerate curve on the way in
///   (quick off the mark, settling gently), an accelerate curve on the way out.
/// * **Follow-through** — rows arrive slightly after the surface and slightly
///   after each other, so the eye is led down the list instead of being handed
///   everything at once.
/// * **Timing** — leaving is faster than arriving (an exit is not worth
///   admiring), and the whole entrance stays under a third of a second.
/// * **Anticipation** — the trigger itself responds to hover and press.
///
/// Nothing overshoots or bounces: this is a reading room.
///
/// It opens on **pointer down**, not on release: a menu that waits for the
/// mouse button to come back up feels a beat behind the hand.
///
/// It does not support press-drag-release the way a native menu bar does.
/// Once a pointer is down, Flutter routes the rest of that pointer's events to
/// the targets hit at the press, so a row never sees the release; supporting
/// it would mean hit-testing the menu by hand from the trigger.
class AnchoredMenu extends StatefulWidget {
  /// The button. It is given whether the menu is open so it can respond.
  final Widget Function(BuildContext context, bool isOpen) trigger;

  /// The rows, in order. Each is staggered on the way in. [close] dismisses.
  final List<Widget> Function(BuildContext context, VoidCallback close) items;

  final double width;
  final String tooltip;

  const AnchoredMenu({
    super.key,
    required this.trigger,
    required this.items,
    required this.tooltip,
    this.width = 260,
  });

  @override
  State<AnchoredMenu> createState() => _AnchoredMenuState();
}

class _AnchoredMenuState extends State<AnchoredMenu>
    with SingleTickerProviderStateMixin {
  static const _enter = Duration(milliseconds: 220);
  static const _leave = Duration(milliseconds: 140);

  final _link = LayerLink();
  final _portal = OverlayPortalController();
  final _triggerFocus = FocusNode(debugLabel: 'Anchored menu trigger');
  final _menuScope = FocusScopeNode(debugLabel: 'Anchored menu');
  late final _motion = AnimationController(
    vsync: this,
    duration: _enter,
    reverseDuration: _leave,
  );
  var _restoreTriggerFocus = false;

  bool get _isOpen => _portal.isShowing;

  @override
  void initState() {
    super.initState();
    _motion.addStatusListener((status) {
      if (status == AnimationStatus.dismissed && _portal.isShowing) {
        _portal.hide();
        setState(() {});
        if (_restoreTriggerFocus) {
          _restoreTriggerFocus = false;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _triggerFocus.requestFocus();
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _motion.dispose();
    _triggerFocus.dispose();
    _menuScope.dispose();
    super.dispose();
  }

  void _open() {
    if (_isOpen) return;
    _restoreTriggerFocus = false;
    _portal.show();
    _motion.forward();
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_isOpen) return;
      for (final node in _menuScope.traversalDescendants) {
        if (node.canRequestFocus) {
          node.requestFocus();
          return;
        }
      }
      _menuScope.requestFocus();
    });
  }

  void _close() {
    if (!_isOpen) return;
    _restoreTriggerFocus = true;
    // The status listener hides the portal once the surface has gone.
    _motion.reverse();
  }

  @override
  Widget build(BuildContext context) {
    // Honour the reader's system setting: no motion, just the menu.
    final still = MediaQuery.disableAnimationsOf(context);
    _motion.duration = still ? Duration.zero : _enter;
    _motion.reverseDuration = still ? Duration.zero : _leave;

    // The trigger shares its press behaviour with every other control in the
    // bar: it acts on the way down, and leans in first.
    final trigger = Pressable(
      onPress: _open,
      active: _isOpen,
      expanded: _isOpen,
      focusNode: _triggerFocus,
      semanticLabel: widget.tooltip,
      tooltip: widget.tooltip,
      child: widget.trigger(context, _isOpen),
    );

    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _portal,
        overlayChildBuilder: (context) => _MenuOverlay(
          link: _link,
          focusScope: _menuScope,
          motion: _motion,
          width: widget.width,
          still: still,
          onDismiss: _close,
          items: widget.items(context, _close),
        ),
        child: trigger,
      ),
    );
  }
}

class _MenuOverlay extends StatelessWidget {
  final LayerLink link;
  final FocusScopeNode focusScope;
  final Animation<double> motion;
  final double width;
  final bool still;
  final VoidCallback onDismiss;
  final List<Widget> items;

  const _MenuOverlay({
    required this.link,
    required this.focusScope,
    required this.motion,
    required this.width,
    required this.still,
    required this.onDismiss,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final chrome = context.chrome;

    // Opacity leads and finishes early; the surface is fully visible while it
    // is still settling, which reads as faster than it is.
    final fade = CurvedAnimation(
      parent: motion,
      curve: const Interval(0, 0.55, curve: Curves.easeOut),
      reverseCurve: Curves.easeIn,
    );
    final grow = CurvedAnimation(
      parent: motion,
      curve: Easing.emphasizedDecelerate,
      reverseCurve: Easing.emphasizedAccelerate,
    );

    // The height available is taken from layout, not from MediaQuery: an
    // OverlayPortal's child inherits from the trigger's place in the tree, so
    // a MediaQuery there could size this menu to nothing.
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight * 0.7
            : 420.0;
        return Stack(
          children: [
            // Anywhere else dismisses, on the press, to match how it opened.
            Positioned.fill(
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (_) => onDismiss(),
              ),
            ),
            CompositedTransformFollower(
              link: link,
              targetAnchor: Alignment.bottomRight,
              followerAnchor: Alignment.topRight,
              offset: const Offset(0, 8),
              // Sized to the menu, not to the screen: an oversized follower
              // paints in the right place but hit-tests in the wrong one.
              child: Align(
                alignment: Alignment.topRight,
                widthFactor: 1,
                heightFactor: 1,
                child: CallbackShortcuts(
                  bindings: {
                    const SingleActivator(LogicalKeyboardKey.escape): onDismiss,
                  },
                  child: FocusScope(
                    node: focusScope,
                    child: AnimatedBuilder(
                      animation: motion,
                      builder: (context, child) => Opacity(
                        opacity: fade.value,
                        child: Transform.translate(
                          // Comes down out of the button rather than
                          // appearing beside it.
                          offset: Offset(0, -10 * (1 - grow.value)),
                          child: Transform.scale(
                            // Never from zero: a surface that starts at 0.94
                            // reads as arriving, not as being inflated.
                            scale: 0.94 + 0.06 * grow.value,
                            alignment: Alignment.topRight,
                            child: child,
                          ),
                        ),
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: chrome.elevated,
                          borderRadius: BorderRadius.circular(
                            LibraryChromeScale.floatingRadius,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: chrome.shadow,
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                            BoxShadow(
                              color: chrome.shadow.withValues(alpha: 0.55),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                            LibraryChromeScale.floatingRadius,
                          ),
                          child: Material(
                            color: chrome.elevated,
                            surfaceTintColor: Colors.transparent,
                            child: Container(
                              width: width,
                              constraints: BoxConstraints(maxHeight: maxHeight),
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    for (var i = 0; i < items.length; i++)
                                      _Staggered(
                                        motion: motion,
                                        index: i,
                                        total: items.length,
                                        still: still,
                                        child: items[i],
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// One row, arriving just after the row above it. On the way out every row
/// leaves together with the surface — an exit should not be a performance.
class _Staggered extends StatelessWidget {
  final Animation<double> motion;
  final int index;
  final int total;
  final bool still;
  final Widget child;

  const _Staggered({
    required this.motion,
    required this.index,
    required this.total,
    required this.still,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (still) return child;

    // The whole cascade is spent by 70% of the entrance, however many rows
    // there are, so a long list never feels slower than a short one.
    final step = total <= 1 ? 0.0 : 0.45 / (total - 1);
    final start = (0.15 + index * step).clamp(0.0, 0.7);
    final arrival = CurvedAnimation(
      parent: motion,
      curve: Interval(
        start,
        (start + 0.3).clamp(0.0, 1.0),
        curve: Curves.easeOutCubic,
      ),
      reverseCurve: const Interval(0, 1),
    );

    return AnimatedBuilder(
      animation: arrival,
      builder: (context, child) => Opacity(
        opacity: arrival.value,
        child: Transform.translate(
          offset: Offset(0, 8 * (1 - arrival.value)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
