import 'package:flutter/material.dart';

import '../theme/library_theme.dart';

/// A code block that can be read: it scrolls rather than clipping, and is
/// never re-wrapped.
class ReadableCodeBlock extends StatefulWidget {
  final String source;
  final List<InlineSpan>? spans;
  final TextStyle textStyle;
  final EdgeInsets padding;
  final Decoration decoration;

  const ReadableCodeBlock({
    super.key,
    required this.source,
    this.spans,
    required this.textStyle,
    required this.padding,
    required this.decoration,
  });

  @override
  State<ReadableCodeBlock> createState() => _ReadableCodeBlockState();
}

class _ReadableCodeBlockState extends State<ReadableCodeBlock> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      decoration: widget.decoration,
      clipBehavior: Clip.antiAlias,
      child: Scrollbar(
        controller: _scroll,
        // Sideways scrolling is easy to miss; the bar is the only sign that
        // there is more line to the right.
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          padding: widget.padding,
          // The reading pane already provides the selection scope; this text
          // only needs its own colour so a highlighted line still reads
          // against the block's background.
          child: Text.rich(
            TextSpan(children: widget.spans ?? [TextSpan(text: widget.source)]),
            style: widget.textStyle.copyWith(
              backgroundColor: Colors.transparent,
            ),
            softWrap: false,
            selectionColor: p.selection,
          ),
        ),
      ),
    );
  }
}
