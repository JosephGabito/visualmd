import 'dart:convert';
import 'dart:isolate';

import 'package:merman/merman.dart';

import '../../application/ports/mermaid_renderer.dart';
import 'svg_style_inliner.dart';

MermaidRenderer createMermaidRenderer() => NativeMermaidRenderer();

/// Renders with Merman's bundled headless engine on desktop and mobile.
///
/// The FFI call performs parsing and graph layout synchronously, so it runs in
/// a worker isolate. Completed SVG is cached by source and palette; resizing,
/// panning, and rebuilding the page never ask the graph engine to work again.
final class NativeMermaidRenderer implements MermaidRenderer {
  final _cache = <String, Future<MermaidRendering>>{};

  @override
  Future<MermaidRendering> render({
    required String source,
    required MermaidPalette palette,
  }) {
    final options = _options(palette);
    final key = '$options\u0000$source';
    return _cache.putIfAbsent(
      key,
      () => Isolate.run(() => _render(source, options)),
    );
  }

  static MermaidRendering _render(String source, String options) {
    final engine = Merman.open();
    final semantic = engine.parseJson(source, optionsJson: options);
    final svg = inlineSvgStyles(engine.renderSvg(source, optionsJson: options));
    return MermaidRendering(
      svg: svg,
      title: _nonEmpty(semantic['accTitle']),
      description: _nonEmpty(semantic['accDescr']),
    );
  }

  static String _options(MermaidPalette palette) => jsonEncode({
    'host_theme': {
      'appearance': palette.dark ? 'dark' : 'light',
      'font_family': 'Inter, system-ui, sans-serif',
      'font_size': '14px',
      'roles': {
        'canvas': palette.canvas,
        'surface': palette.surface,
        'surface_alt': palette.canvas,
        'text': palette.text,
        'subtle_text': palette.subtleText,
        'border': palette.border,
        'line': palette.line,
        'success': palette.accent,
      },
      'series_palette': [palette.accent, palette.line, palette.subtleText],
      'output': {
        // flutter_svg is intentionally the inert consumer. The safe pipeline
        // preserves labels and markers without admitting HTML surfaces.
        'pipeline': 'resvg-safe',
        'root_background': 'canvas',
        'drop_native_duplicate_fallbacks': true,
        'css_override_policy': 'strip-existing-important',
      },
    },
  });
}

String? _nonEmpty(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  return value.trim();
}
