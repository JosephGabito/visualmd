import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../application/ports/mermaid_renderer.dart';
import '../theme/library_chrome.dart';
import '../theme/library_theme.dart';

/// A Mermaid diagram with a quiet reading state and an exploratory state.
///
/// The document first shows the whole diagram fitted into a bounded viewport.
/// Dragging pans, wheel or pinch gestures zoom, and the same model can occupy a
/// distraction-free full-screen surface. The SVG remains inert data throughout;
/// authored Mermaid actions never become application actions.
final class ReadableMermaidDiagram extends StatefulWidget {
  final String source;
  final MermaidRenderer renderer;
  final MermaidPalette palette;
  final double beat;

  const ReadableMermaidDiagram({
    super.key,
    required this.source,
    required this.renderer,
    required this.palette,
    required this.beat,
  });

  @override
  State<ReadableMermaidDiagram> createState() => _ReadableMermaidDiagramState();
}

final class _ReadableMermaidDiagramState extends State<ReadableMermaidDiagram> {
  MermaidRendering? _rendering;
  Object? _failure;
  var _request = 0;

  @override
  void initState() {
    super.initState();
    _render();
  }

  @override
  void didUpdateWidget(ReadableMermaidDiagram oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source ||
        !identical(oldWidget.renderer, widget.renderer) ||
        !_samePalette(oldWidget.palette, widget.palette)) {
      _rendering = null;
      _failure = null;
      _render();
    }
  }

  Future<void> _render() async {
    final request = ++_request;
    try {
      final rendering = await widget.renderer.render(
        source: widget.source,
        palette: widget.palette,
      );
      if (!mounted || request != _request) return;
      setState(() => _rendering = rendering);
    } catch (error) {
      if (!mounted || request != _request) return;
      setState(() => _failure = error);
    }
  }

  @override
  void dispose() {
    _request++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rendering = _rendering;
    if (rendering != null) {
      final geometry = _SvgGeometry.read(rendering.svg);
      if (geometry != null) {
        return _MermaidExplorer(
          source: widget.source,
          rendering: rendering,
          geometry: geometry,
          beat: widget.beat,
        );
      }
    }
    if (_failure != null || rendering != null) {
      return _MermaidFallback(source: widget.source, beat: widget.beat);
    }
    return Semantics(
      label: 'Rendering Mermaid diagram',
      child: SizedBox(
        key: const ValueKey('mermaid-loading'),
        height: widget.beat * 8,
        child: Center(
          child: SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: context.palette.muted,
            ),
          ),
        ),
      ),
    );
  }
}

final class _MermaidExplorer extends StatefulWidget {
  final String source;
  final MermaidRendering rendering;
  final _SvgGeometry geometry;
  final double beat;
  final bool fullScreen;

  const _MermaidExplorer({
    required this.source,
    required this.rendering,
    required this.geometry,
    required this.beat,
    this.fullScreen = false,
  });

  @override
  State<_MermaidExplorer> createState() => _MermaidExplorerState();
}

final class _MermaidExplorerState extends State<_MermaidExplorer> {
  final _transformation = TransformationController();
  Timer? _copyFeedback;
  Size? _viewport;
  bool _shouldFit = true;
  bool _dragging = false;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _transformation.addListener(_keepReachable);
  }

  @override
  void dispose() {
    _copyFeedback?.cancel();
    _transformation.removeListener(_keepReachable);
    _transformation.dispose();
    super.dispose();
  }

  /// Leaves a graspable part of the diagram inside its viewport.
  ///
  /// An infinite InteractiveViewer boundary is necessary because fit-to-page
  /// can begin below a scale of one. It also means a quick desktop fling could
  /// otherwise send the complete figure into empty space. Constraining only
  /// the final painted bounds preserves free exploration while guaranteeing a
  /// reader can always drag the figure back without reaching for reset.
  void _keepReachable() {
    final viewport = _viewport;
    if (viewport == null) return;
    final matrix = _transformation.value;
    final bounds = MatrixUtils.transformRect(
      matrix,
      Offset.zero & widget.geometry.size,
    );
    // A sliver of SVG can be only empty viewBox padding. Keep nearly a third
    // of the shorter viewport (up to 320 px), enough to expose graph content
    // and make the return drag obvious without restricting close inspection.
    final visible = math.min(
      320.0,
      math.min(viewport.width, viewport.height) * 0.3,
    );
    var dx = 0.0;
    var dy = 0.0;
    if (bounds.right < visible) {
      dx = visible - bounds.right;
    } else if (bounds.left > viewport.width - visible) {
      dx = viewport.width - visible - bounds.left;
    }
    if (bounds.bottom < visible) {
      dy = visible - bounds.bottom;
    } else if (bounds.top > viewport.height - visible) {
      dy = viewport.height - visible - bounds.top;
    }
    if (dx == 0 && dy == 0) return;
    final corrected = Matrix4.copy(matrix);
    corrected.setTranslationRaw(
      matrix.storage[12] + dx,
      matrix.storage[13] + dy,
      matrix.storage[14],
    );
    _transformation.value = corrected;
  }

  void _fit(Size viewport) {
    final diagram = widget.geometry.size;
    final scale = math.min(
      viewport.width / diagram.width,
      viewport.height / diagram.height,
    );
    final dx = (viewport.width - diagram.width * scale) / 2;
    final dy = (viewport.height - diagram.height * scale) / 2;
    _transformation.value = Matrix4.identity()
      ..translateByDouble(dx, dy, 0, 1)
      ..scaleByDouble(scale, scale, scale, 1);
    _shouldFit = false;
  }

  void _scheduleFit(Size viewport) {
    if (!_shouldFit && _viewport == viewport) return;
    _viewport = viewport;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _viewport != viewport) return;
      _fit(viewport);
    });
  }

  void _zoom(double factor) {
    final viewport = _viewport;
    if (viewport == null) return;
    final focal = _transformation.toScene(viewport.center(Offset.zero));
    final matrix = Matrix4.copy(_transformation.value)
      ..translateByDouble(focal.dx, focal.dy, 0, 1)
      ..scaleByDouble(factor, factor, factor, 1)
      ..translateByDouble(-focal.dx, -focal.dy, 0, 1);
    _transformation.value = matrix;
    _shouldFit = false;
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.source));
    if (!mounted) return;
    _copyFeedback?.cancel();
    setState(() => _copied = true);
    _copyFeedback = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  Future<void> _openFullScreen() async {
    final p = context.palette;
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: p.paper,
      transitionDuration: const Duration(milliseconds: 180),
      transitionBuilder: (context, animation, secondary, child) =>
          FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          ),
      pageBuilder: (context, primary, secondary) => Material(
        color: p.paper,
        child: SafeArea(
          child: _MermaidExplorer(
            source: widget.source,
            rendering: widget.rendering,
            geometry: widget.geometry,
            beat: widget.beat,
            fullScreen: true,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final accessibleName = widget.rendering.title ?? 'Mermaid diagram';
    final accessibleDescription = widget.rendering.description;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.equal, meta: true): () =>
            _zoom(1.2),
        const SingleActivator(LogicalKeyboardKey.equal, control: true): () =>
            _zoom(1.2),
        const SingleActivator(LogicalKeyboardKey.minus, meta: true): () =>
            _zoom(1 / 1.2),
        const SingleActivator(LogicalKeyboardKey.minus, control: true): () =>
            _zoom(1 / 1.2),
        const SingleActivator(LogicalKeyboardKey.digit0, meta: true): () {
          final viewport = _viewport;
          if (viewport != null) _fit(viewport);
        },
        const SingleActivator(LogicalKeyboardKey.digit0, control: true): () {
          final viewport = _viewport;
          if (viewport != null) _fit(viewport);
        },
        if (widget.fullScreen) ...{
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              Navigator.of(context).pop(),
          const SingleActivator(LogicalKeyboardKey.period, meta: true): () =>
              Navigator.of(context).pop(),
        },
      },
      child: Focus(
        autofocus: widget.fullScreen,
        child: SelectionContainer.disabled(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final headerHeight = widget.beat;
              final bodyHeight = widget.fullScreen
                  ? math.max(0.0, constraints.maxHeight - headerHeight)
                  : _inlineHeight(constraints.maxWidth);
              final viewport = Size(constraints.maxWidth, bodyHeight);
              _scheduleFit(viewport);

              return Semantics(
                container: true,
                image: true,
                label: accessibleName,
                value: accessibleDescription,
                child: ClipRRect(
                  key: const ValueKey('mermaid-surface'),
                  borderRadius: widget.fullScreen
                      ? BorderRadius.zero
                      : BorderRadius.circular(
                          LibraryChromeScale.componentRadius,
                        ),
                  child: ColoredBox(
                    color: p.paper,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _toolbar(headerHeight),
                        SizedBox(
                          key: const ValueKey('mermaid-viewport'),
                          height: bodyHeight,
                          child: MouseRegion(
                            cursor: _dragging
                                ? SystemMouseCursors.grabbing
                                : SystemMouseCursors.grab,
                            child: Listener(
                              onPointerDown: (_) =>
                                  setState(() => _dragging = true),
                              onPointerUp: (_) =>
                                  setState(() => _dragging = false),
                              onPointerCancel: (_) =>
                                  setState(() => _dragging = false),
                              child: RepaintBoundary(
                                child: InteractiveViewer(
                                  key: const ValueKey('mermaid-interactive'),
                                  transformationController: _transformation,
                                  alignment: Alignment.topLeft,
                                  constrained: false,
                                  boundaryMargin: const EdgeInsets.all(
                                    double.infinity,
                                  ),
                                  minScale: 0.02,
                                  maxScale: 8,
                                  trackpadScrollCausesScale: true,
                                  onInteractionStart: (_) {
                                    _shouldFit = false;
                                  },
                                  child: SizedBox(
                                    width: widget.geometry.width,
                                    height: widget.geometry.height,
                                    child: SvgPicture.string(
                                      widget.rendering.svg,
                                      key: const ValueKey('mermaid-svg'),
                                      fit: BoxFit.fill,
                                      clipBehavior: Clip.none,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  double _inlineHeight(double width) {
    final natural = width * widget.geometry.height / widget.geometry.width;
    return natural.clamp(widget.beat * 8, widget.beat * 18);
  }

  Widget _toolbar(double extent) {
    final chrome = context.chrome;
    return SizedBox(
      key: const ValueKey('mermaid-toolbar'),
      height: extent,
      child: ColoredBox(
        color: chrome.elevated,
        child: Padding(
          padding: EdgeInsets.only(left: widget.beat * 0.45),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.rendering.title ?? 'Diagram',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.chromeComponentLabel,
                ),
              ),
              _DiagramAction(
                key: const ValueKey('mermaid-zoom-out'),
                label: 'Zoom out (⌘− / Ctrl−)',
                icon: Icons.remove_rounded,
                extent: extent,
                onPressed: () => _zoom(1 / 1.2),
              ),
              _DiagramAction(
                key: const ValueKey('mermaid-zoom-in'),
                label: 'Zoom in (⌘+ / Ctrl+)',
                icon: Icons.add_rounded,
                extent: extent,
                onPressed: () => _zoom(1.2),
              ),
              _DiagramAction(
                key: const ValueKey('mermaid-reset'),
                label: 'Fit diagram (⌘0 / Ctrl+0)',
                icon: Icons.fit_screen_rounded,
                extent: extent,
                onPressed: () {
                  final viewport = _viewport;
                  if (viewport != null) _fit(viewport);
                },
              ),
              if (!widget.fullScreen)
                _DiagramAction(
                  key: const ValueKey('mermaid-fullscreen'),
                  label: 'View diagram full screen',
                  icon: Icons.fullscreen_rounded,
                  extent: extent,
                  onPressed: _openFullScreen,
                )
              else
                _DiagramAction(
                  key: const ValueKey('mermaid-close-fullscreen'),
                  label: 'Close full screen',
                  icon: Icons.fullscreen_exit_rounded,
                  extent: extent,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              _DiagramAction(
                key: const ValueKey('mermaid-copy'),
                label: _copied
                    ? 'Mermaid source copied'
                    : 'Copy Mermaid source',
                icon: _copied
                    ? Icons.check_rounded
                    : Icons.content_copy_rounded,
                extent: extent,
                onPressed: _copy,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _MermaidFallback extends StatefulWidget {
  final String source;
  final double beat;

  const _MermaidFallback({required this.source, required this.beat});

  @override
  State<_MermaidFallback> createState() => _MermaidFallbackState();
}

final class _MermaidFallbackState extends State<_MermaidFallback> {
  var _copied = false;
  Timer? _feedback;

  @override
  void dispose() {
    _feedback?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.source));
    if (!mounted) return;
    _feedback?.cancel();
    setState(() => _copied = true);
    _feedback = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      container: true,
      label: 'Mermaid diagram could not be rendered; source follows',
      child: ClipRRect(
        key: const ValueKey('mermaid-fallback'),
        borderRadius: BorderRadius.circular(LibraryChromeScale.componentRadius),
        child: ColoredBox(
          color: p.codeBackground,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: widget.beat,
                child: Padding(
                  padding: EdgeInsets.only(left: widget.beat * 0.45),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Mermaid source',
                          style: context.chromeComponentLabel,
                        ),
                      ),
                      _DiagramAction(
                        label: _copied ? 'Source copied' : 'Copy source',
                        icon: _copied
                            ? Icons.check_rounded
                            : Icons.content_copy_rounded,
                        extent: widget.beat,
                        onPressed: _copy,
                      ),
                    ],
                  ),
                ),
              ),
              ColoredBox(
                color: Color.lerp(
                  p.codeBackground,
                  Theme.of(context).brightness == Brightness.dark
                      ? Colors.black
                      : Colors.white,
                  0.09,
                )!,
                child: Padding(
                  padding: EdgeInsets.all(widget.beat * 0.55),
                  child: Text(
                    widget.source,
                    style: context.type.mono(
                      color: p.ink,
                      size: 13,
                      height: 1.45,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _DiagramAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final double extent;
  final VoidCallback onPressed;

  const _DiagramAction({
    super.key,
    required this.label,
    required this.icon,
    required this.extent,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    child: IconButton(
      constraints: BoxConstraints.tightFor(width: extent, height: extent),
      padding: EdgeInsets.zero,
      splashRadius: extent * 0.42,
      iconSize: math.min(18, extent * 0.52),
      color: context.palette.muted,
      onPressed: onPressed,
      tooltip: null,
      icon: Icon(icon, semanticLabel: label),
    ),
  );
}

final class _SvgGeometry {
  final double width;
  final double height;

  const _SvgGeometry(this.width, this.height);

  Size get size => Size(width, height);

  static _SvgGeometry? read(String svg) {
    final match = RegExp(
      r'''viewBox\s*=\s*["']\s*[-+\d.eE]+[\s,]+[-+\d.eE]+[\s,]+([-+\d.eE]+)[\s,]+([-+\d.eE]+)\s*["']''',
      caseSensitive: false,
    ).firstMatch(svg);
    if (match == null) return null;
    final width = double.tryParse(match.group(1)!);
    final height = double.tryParse(match.group(2)!);
    if (width == null || height == null || width <= 0 || height <= 0) {
      return null;
    }
    return _SvgGeometry(width, height);
  }
}

bool _samePalette(MermaidPalette a, MermaidPalette b) =>
    a.canvas == b.canvas &&
    a.surface == b.surface &&
    a.text == b.text &&
    a.subtleText == b.subtleText &&
    a.border == b.border &&
    a.line == b.line &&
    a.accent == b.accent &&
    a.dark == b.dark;
