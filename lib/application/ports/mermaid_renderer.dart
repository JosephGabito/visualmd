/// The colours a Mermaid engine may use to make a diagram belong to the page.
///
/// Hex strings cross this framework-free seam because neither a Flutter
/// [Color] nor an engine-specific theme object belongs in the application
/// contract.
final class MermaidPalette {
  final String canvas;
  final String surface;
  final String text;
  final String subtleText;
  final String border;
  final String line;
  final String accent;
  final bool dark;

  const MermaidPalette({
    required this.canvas,
    required this.surface,
    required this.text,
    required this.subtleText,
    required this.border,
    required this.line,
    required this.accent,
    required this.dark,
  });
}

/// A successful rendering of authored Mermaid source.
final class MermaidRendering {
  final String svg;
  final String? title;
  final String? description;

  const MermaidRendering({required this.svg, this.title, this.description});
}

/// Turns Mermaid source into inert SVG data.
///
/// Rendering is asynchronous because a native adapter may work in an isolate
/// and a web adapter may cross into a bundled JavaScript engine. Failure is
/// reported by throwing; the reading component owns the durable fallback to
/// the exact source and never lets an enhancement hide authored material.
abstract interface class MermaidRenderer {
  Future<MermaidRendering> render({
    required String source,
    required MermaidPalette palette,
  });
}

/// The kernel fallback for targets without a Mermaid engine.
final class UnavailableMermaidRenderer implements MermaidRenderer {
  const UnavailableMermaidRenderer();

  @override
  Future<MermaidRendering> render({
    required String source,
    required MermaidPalette palette,
  }) => Future.error(
    UnsupportedError('Mermaid rendering is unavailable on this target'),
  );
}
