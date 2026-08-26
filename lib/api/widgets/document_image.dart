import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../application/ports/document_image_loader.dart';
import '../../domain/library/document_id.dart';
import '../render/reading_theme.dart';

/// One authored Markdown image, loaded without letting its source escape the
/// document capability that owns it.
final class DocumentImage extends StatefulWidget {
  final DocumentId? document;
  final String source;
  final String alt;
  final String? title;
  final DocumentImageLoader? loader;
  final ReadingTheme theme;

  const DocumentImage({
    super.key,
    required this.document,
    required this.source,
    required this.alt,
    required this.title,
    required this.loader,
    required this.theme,
  });

  @override
  State<DocumentImage> createState() => _DocumentImageState();
}

final class _DocumentImageState extends State<DocumentImage> {
  Future<Uint8List?>? _bytes;

  @override
  void initState() {
    super.initState();
    _beginLocalLoad();
  }

  @override
  void didUpdateWidget(DocumentImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.document != widget.document ||
        oldWidget.source != widget.source ||
        oldWidget.loader != widget.loader) {
      _beginLocalLoad();
    }
  }

  void _beginLocalLoad() {
    final document = widget.document;
    final loader = widget.loader;
    _bytes =
        _remote(widget.source) != null || document == null || loader == null
        ? null
        : loader.load(document, widget.source);
  }

  @override
  Widget build(BuildContext context) {
    final remote = _remote(widget.source);
    if (remote != null) {
      return _bounded(
        context,
        (cacheWidth) => Image.network(
          remote.toString(),
          semanticLabel: widget.alt.isEmpty ? null : widget.alt,
          excludeFromSemantics: widget.alt.isEmpty,
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          filterQuality: FilterQuality.medium,
          cacheWidth: cacheWidth,
          webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
          loadingBuilder: (_, child, progress) =>
              progress == null ? child : _alternative(failed: false),
          errorBuilder: (_, _, _) => _alternative(failed: true),
        ),
      );
    }

    final bytes = _bytes;
    if (bytes == null) return _alternative(failed: true);
    return FutureBuilder<Uint8List?>(
      future: bytes,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _alternative(failed: false);
        }
        final data = snapshot.data;
        if (data == null || snapshot.hasError) {
          return _alternative(failed: true);
        }
        return _bounded(
          context,
          (cacheWidth) => Image.memory(
            data,
            semanticLabel: widget.alt.isEmpty ? null : widget.alt,
            excludeFromSemantics: widget.alt.isEmpty,
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            filterQuality: FilterQuality.medium,
            cacheWidth: cacheWidth,
            errorBuilder: (_, _, _) => _alternative(failed: true),
          ),
        );
      },
    );
  }

  Widget _bounded(
    BuildContext context,
    Widget Function(int cacheWidth) image,
  ) => LayoutBuilder(
    builder: (context, constraints) {
      final viewport = MediaQuery.sizeOf(context);
      final maxWidth = constraints.hasBoundedWidth
          ? constraints.maxWidth
          : viewport.width;
      final availableHeight = viewport.height * 0.72;
      final maxHeight = availableHeight < widget.theme.baseline
          ? availableHeight
          : (availableHeight / widget.theme.baseline).floor() *
                widget.theme.baseline;
      final pixels = MediaQuery.devicePixelRatioOf(context);
      final child = _RhythmicImage(
        beat: widget.theme.baseline,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
          child: image((maxWidth * pixels).round().clamp(1, 4096)),
        ),
      );
      final title = widget.title;
      return title == null || title.isEmpty
          ? child
          : Tooltip(message: title, child: child);
    },
  );

  Widget _alternative({required bool failed}) {
    final label = widget.alt.isNotEmpty
        ? widget.alt
        : failed
        ? 'Image unavailable'
        : 'Loading image';
    final alternative = Text(
      label,
      style: widget.theme.body.copyWith(color: widget.theme.palette.muted),
    );
    return widget.alt.isEmpty
        ? ExcludeSemantics(child: alternative)
        : alternative;
  }
}

/// Lets artwork keep its intrinsic geometry, then spends the remaining part
/// of a body line below it so running text resumes on the baseline grid.
final class _RhythmicImage extends SingleChildRenderObjectWidget {
  final double beat;

  const _RhythmicImage({required this.beat, required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderRhythmicImage(beat);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderRhythmicImage renderObject,
  ) {
    renderObject.beat = beat;
  }
}

final class _RenderRhythmicImage extends RenderShiftedBox {
  _RenderRhythmicImage(this._beat, [RenderBox? child]) : super(child);

  double _beat;
  set beat(double value) {
    if (_beat == value) return;
    _beat = value;
    markNeedsLayout();
  }

  BoxConstraints _childConstraints(BoxConstraints constraints) =>
      constraints.copyWith(minWidth: 0, minHeight: 0);

  Size _sizeFor(Size childSize, BoxConstraints constraints) =>
      constraints.constrain(
        Size(childSize.width, (childSize.height / _beat).ceil() * _beat),
      );

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final childSize = child?.getDryLayout(_childConstraints(constraints));
    return childSize == null
        ? constraints.smallest
        : _sizeFor(childSize, constraints);
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(_childConstraints(constraints), parentUsesSize: true);
    size = _sizeFor(child.size, constraints);
    (child.parentData! as BoxParentData).offset = Offset.zero;
  }
}

Uri? _remote(String source) {
  final uri = Uri.tryParse(source);
  return uri != null && (uri.scheme == 'http' || uri.scheme == 'https')
      ? uri
      : null;
}
