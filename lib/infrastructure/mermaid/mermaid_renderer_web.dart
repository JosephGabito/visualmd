import 'dart:convert';
import 'dart:js_interop';

import '../../application/ports/mermaid_renderer.dart';
import 'svg_style_inliner.dart';

MermaidRenderer createMermaidRenderer() => WebMermaidRenderer();

@JS('visualMdRenderMermaid')
external JSPromise<JSString> _renderMermaid(
  JSString source,
  JSString paletteJson,
);

/// Uses the pinned Mermaid bundle shipped with the web application.
///
/// The bridge returns SVG as data; it is never installed into the browser DOM.
/// Flutter therefore owns painting and interaction exactly as it does on the
/// desktop targets.
final class WebMermaidRenderer implements MermaidRenderer {
  final _cache = <String, Future<MermaidRendering>>{};

  @override
  Future<MermaidRendering> render({
    required String source,
    required MermaidPalette palette,
  }) {
    final options = jsonEncode({
      'canvas': palette.canvas,
      'surface': palette.surface,
      'text': palette.text,
      'subtleText': palette.subtleText,
      'border': palette.border,
      'line': palette.line,
      'accent': palette.accent,
      'dark': palette.dark,
    });
    final key = '$options\u0000$source';
    return _cache.putIfAbsent(key, () async {
      final raw = await _renderMermaid(source.toJS, options.toJS).toDart;
      final json = jsonDecode(raw.toDart) as Map<String, Object?>;
      return MermaidRendering(
        svg: inlineSvgStyles(json['svg']! as String),
        title: _nonEmpty(json['title']),
        description: _nonEmpty(json['description']),
      );
    });
  }
}

String? _nonEmpty(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  return value.trim();
}
