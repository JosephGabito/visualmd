import 'package:flutter/material.dart';

import '../theme/library_chrome.dart';
import '../theme/library_theme.dart';

/// One navigational row shared by the shelf and document outline.
///
/// Selection, hover, focus, height and radius are one visual language. The
/// caller owns indentation and content because tree geometry is semantic, not
/// decoration.
final class ChromeListRow extends StatefulWidget {
  final bool selected;
  final bool showLocation;
  final VoidCallback? onTap;
  final GestureTapDownCallback? onSecondaryTapDown;
  final EdgeInsetsGeometry padding;
  final Widget child;

  const ChromeListRow({
    super.key,
    this.selected = false,
    this.showLocation = false,
    required this.onTap,
    this.onSecondaryTapDown,
    required this.padding,
    required this.child,
  });

  @override
  State<ChromeListRow> createState() => _ChromeListRowState();
}

final class _ChromeListRowState extends State<ChromeListRow> {
  var _focused = false;

  @override
  Widget build(BuildContext context) {
    final chrome = context.chrome;
    final radius = BorderRadius.circular(LibraryChromeScale.rowRadius);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: LibraryChromeScale.row),
      child: Ink(
        decoration: BoxDecoration(
          color: widget.selected ? chrome.selected : Colors.transparent,
          borderRadius: radius,
          border: Border.all(
            color: _focused ? chrome.focus : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: InkWell(
          onTap: widget.onTap,
          onSecondaryTapDown: widget.onSecondaryTapDown,
          onFocusChange: (focused) => setState(() => _focused = focused),
          borderRadius: radius,
          hoverColor: widget.selected ? chrome.selectedHover : chrome.hover,
          focusColor: Colors.transparent,
          highlightColor: chrome.pressed,
          child: Stack(
            children: [
              if (widget.showLocation)
                Positioned(
                  left: 0,
                  top: LibraryChromeScale.space2,
                  bottom: LibraryChromeScale.space2,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: context.palette.accent,
                      borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(2),
                      ),
                    ),
                    child: const SizedBox(width: 3),
                  ),
                ),
              Padding(padding: widget.padding, child: widget.child),
            ],
          ),
        ),
      ),
    );
  }
}
