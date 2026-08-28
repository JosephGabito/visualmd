import 'dart:async';

import 'package:flutter/material.dart';

import '../../application/ports/document_viewport_geometry.dart';
import '../theme/library_theme.dart';

/// Connects pre-paint document corrections to a visible scrollbar epoch.
///
/// The controller does not own scroll position. It only teaches the frozen
/// thumb which physical movement came from layout rather than from the reader.
final class QuietScrollbarController {
  _QuietScrollbarState? _state;

  void _attach(_QuietScrollbarState state) => _state = state;

  void _detach(_QuietScrollbarState state) {
    if (identical(_state, state)) _state = null;
  }

  void absorb(DocumentExtentCorrection correction) =>
      _state?._absorb(correction);
}

/// A scrollbar whose visible geometry belongs to one interaction epoch.
///
/// Flutter's live scroll metrics can change while a lazy document lays out or
/// receives a streamed tail. Recomputing the thumb from every such correction
/// makes it resize under the reader's pointer. This widget freezes the content
/// extent when the thumb appears and keeps that coordinate system until the
/// thumb has faded completely. User movement still updates the thumb; layout
/// movement does not redefine it halfway through the interaction.
final class QuietScrollbar extends StatefulWidget {
  final ScrollController controller;
  final DocumentViewportGeometryFactory geometryFactory;
  final QuietScrollbarController? epochController;
  final Widget child;
  final Duration fadeDelay;
  final Duration fadeDuration;
  final double minimumThumbExtent;

  const QuietScrollbar({
    super.key,
    required this.controller,
    required this.geometryFactory,
    this.epochController,
    required this.child,
    this.fadeDelay = const Duration(milliseconds: 650),
    this.fadeDuration = const Duration(milliseconds: 180),
    this.minimumThumbExtent = 28,
  });

  @override
  State<QuietScrollbar> createState() => _QuietScrollbarState();
}

final class _QuietScrollbarState extends State<QuietScrollbar>
    with SingleTickerProviderStateMixin {
  static const _trackInset = 3.0;
  static const _thumbWidth = 5.0;
  static const _hitWidth = 16.0;

  late final AnimationController _opacity = AnimationController(
    vsync: this,
    duration: widget.fadeDuration,
  );
  FrozenDocumentScrollMetrics? _frozen;
  Timer? _fadeTimer;
  double? _dragGrabOffset;

  ScrollPosition? get _position =>
      widget.controller.hasClients ? widget.controller.position : null;

  @override
  void initState() {
    super.initState();
    widget.epochController?._attach(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _opacity.duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : widget.fadeDuration;
  }

  @override
  void didUpdateWidget(QuietScrollbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) _finishEpoch();
    if (oldWidget.epochController != widget.epochController) {
      oldWidget.epochController?._detach(this);
      widget.epochController?._attach(this);
    }
    if (oldWidget.fadeDuration != widget.fadeDuration) {
      _opacity.duration = MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : widget.fadeDuration;
    }
  }

  @override
  void dispose() {
    widget.epochController?._detach(this);
    _fadeTimer?.cancel();
    _opacity.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    switch (notification) {
      case ScrollStartNotification():
        _beginEpoch(notification.metrics);
      case ScrollUpdateNotification() || OverscrollNotification():
        _beginEpoch(notification.metrics);
        setState(() {});
      case ScrollEndNotification():
        _scheduleFade();
      default:
        break;
    }
    return false;
  }

  void _beginEpoch(ScrollMetrics metrics) {
    _fadeTimer?.cancel();
    _frozen ??= widget.geometryFactory.freezeMetrics(
      contentExtent:
          metrics.maxScrollExtent -
          metrics.minScrollExtent +
          metrics.viewportDimension,
      viewportExtent: metrics.viewportDimension,
    );
    _opacity.forward();
  }

  void _scheduleFade() {
    _fadeTimer?.cancel();
    _fadeTimer = Timer(widget.fadeDelay, () async {
      if (!mounted || _dragGrabOffset != null) return;
      await _opacity.reverse();
      if (mounted && _opacity.isDismissed) {
        setState(() => _frozen = null);
      }
    });
  }

  void _finishEpoch() {
    _fadeTimer?.cancel();
    _dragGrabOffset = null;
    _frozen = null;
    _opacity.value = 0;
  }

  void _absorb(DocumentExtentCorrection correction) {
    _frozen?.absorb(correction);
  }

  DocumentScrollThumb? _thumb(double height) {
    final position = _position;
    final frozen = _frozen;
    final trackExtent = (height - _trackInset * 2)
        .clamp(0.0, double.infinity)
        .toDouble();
    if (position == null || frozen == null || trackExtent == 0) return null;
    return frozen.thumb(
      physicalPixels: position.pixels,
      trackExtent: trackExtent,
      minimumThumbExtent: widget.minimumThumbExtent,
    );
  }

  void _startDrag(DragStartDetails details, double height) {
    final position = _position;
    if (position == null) return;
    _beginEpoch(position);
    final thumb = _thumb(height);
    if (thumb == null) return;
    final local = details.localPosition.dy - _trackInset;
    final inside =
        local >= thumb.offset && local <= thumb.offset + thumb.extent;
    _dragGrabOffset = inside ? local - thumb.offset : thumb.extent / 2;
    if (!inside) _dragTo(details.localPosition.dy, height);
    setState(() {});
  }

  void _updateDrag(DragUpdateDetails details, double height) {
    if (_dragGrabOffset == null) return;
    _dragTo(details.localPosition.dy, height);
  }

  void _dragTo(double pointerY, double height) {
    final position = _position;
    final frozen = _frozen;
    final grab = _dragGrabOffset;
    final thumb = _thumb(height);
    if (position == null || frozen == null || grab == null || thumb == null) {
      return;
    }
    final trackExtent = height - _trackInset * 2;
    final travel = trackExtent - thumb.extent;
    if (travel <= 0) return;
    final offset = (pointerY - _trackInset - grab).clamp(0.0, travel);
    final logical = offset / travel * frozen.maximumScrollExtent;
    final physical = (logical + frozen.correctionBias).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    position.jumpTo(physical);
    setState(() {});
  }

  void _endDrag(DragEndDetails details) {
    _dragGrabOffset = null;
    _scheduleFade();
  }

  @override
  Widget build(BuildContext context) {
    final thumbColor = context.palette.muted.withValues(
      alpha: Theme.of(context).brightness == Brightness.dark ? 0.72 : 0.62,
    );
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxHeight;
          final thumb = _thumb(height);
          return Stack(
            fit: StackFit.expand,
            children: [
              ScrollConfiguration(
                behavior: ScrollConfiguration.of(context)
                    .copyWith(scrollbars: false),
                child: widget.child,
              ),
              if (thumb != null)
                Positioned(
                  key: const ValueKey('quiet-scrollbar-thumb'),
                  top: _trackInset + thumb.offset,
                  right: _trackInset,
                  width: _thumbWidth,
                  height: thumb.extent,
                  child: IgnorePointer(
                    child: FadeTransition(
                      opacity: _opacity,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: thumbColor,
                          borderRadius: BorderRadius.circular(_thumbWidth / 2),
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                top: 0,
                right: 0,
                bottom: 0,
                width: _hitWidth,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onVerticalDragStart: (details) => _startDrag(details, height),
                  onVerticalDragUpdate: (details) =>
                      _updateDrag(details, height),
                  onVerticalDragEnd: _endDrag,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
