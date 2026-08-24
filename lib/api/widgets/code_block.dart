import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../presentation/code/code_highlighter.dart';
import '../theme/library_theme.dart';

/// A fenced block with a quiet identity and two reading actions.
///
/// The source is always rendered first and remains the authority for selection
/// and copying. Highlighting may arrive later or not at all. Lines scroll by
/// default because wrapping changes how code appears to be structured; the
/// reader may opt into wrapping for one block when comprehension benefits.
final class ReadableCodeBlock extends StatefulWidget {
  final String source;
  final String? language;
  final CodeHighlighter highlighter;
  final CodeHighlightScheme scheme;
  final List<InlineSpan> Function(CodeHighlighting? highlighting) spansFor;
  final TextStyle textStyle;
  final Color bodyBackground;
  final double beat;
  final double headerHeight;
  final EdgeInsets padding;
  final Decoration decoration;

  const ReadableCodeBlock({
    super.key,
    required this.source,
    required this.language,
    required this.highlighter,
    required this.scheme,
    required this.spansFor,
    required this.textStyle,
    required this.bodyBackground,
    required this.beat,
    required this.headerHeight,
    required this.padding,
    required this.decoration,
  });

  @override
  State<ReadableCodeBlock> createState() => _ReadableCodeBlockState();
}

final class _ReadableCodeBlockState extends State<ReadableCodeBlock> {
  final _scroll = ScrollController();
  CodeHighlighting? _highlighting;
  Timer? _copyFeedback;
  var _request = 0;
  var _wrap = false;
  var _copied = false;

  @override
  void initState() {
    super.initState();
    _loadHighlighting();
  }

  @override
  void didUpdateWidget(ReadableCodeBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source ||
        oldWidget.language != widget.language ||
        oldWidget.scheme != widget.scheme ||
        !identical(oldWidget.highlighter, widget.highlighter)) {
      _highlighting = null;
      _loadHighlighting();
    }
  }

  Future<void> _loadHighlighting() async {
    final request = ++_request;
    CodeHighlighting? result;
    try {
      result = await widget.highlighter.highlight(
        source: widget.source,
        language: widget.language,
        scheme: widget.scheme,
      );
    } catch (_) {
      // A third-party contributor is held to the same fallback contract as
      // the bundled one: enhancement failure cannot hide the source.
      result = null;
    }
    if (!mounted || request != _request) return;
    setState(() => _highlighting = result);
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

  @override
  void dispose() {
    _request++;
    _copyFeedback?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final spans = widget.spansFor(_highlighting);
    final text = Text.rich(
      TextSpan(children: spans),
      key: const ValueKey('code-source'),
      style: widget.textStyle.copyWith(backgroundColor: Colors.transparent),
      softWrap: _wrap,
      selectionColor: p.selection,
    );

    final body = _wrap
        ? Padding(padding: widget.padding, child: text)
        : ScrollbarTheme(
            data: ScrollbarTheme.of(context).copyWith(
              thickness: const WidgetStatePropertyAll(4),
              radius: const Radius.circular(8),
              thumbColor: WidgetStatePropertyAll(
                p.muted.withValues(alpha: 0.55),
              ),
              trackVisibility: const WidgetStatePropertyAll(false),
            ),
            child: Scrollbar(
              controller: _scroll,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _scroll,
                scrollDirection: Axis.horizontal,
                padding: widget.padding,
                child: text,
              ),
            ),
          );

    return Container(
      key: const ValueKey('code-block-surface'),
      decoration: widget.decoration,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SelectionContainer.disabled(
            child: SizedBox(
              height: widget.headerHeight,
              child: Padding(
                padding: EdgeInsets.only(left: widget.padding.left),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.highlighter.labelFor(widget.language),
                        key: const ValueKey('code-language'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.type
                            .sans(
                              color: p.muted,
                              size: 12,
                              height: 1,
                              weight: FontWeight.w500,
                            )
                            .copyWith(letterSpacing: 0.15),
                      ),
                    ),
                    _CodeAction(
                      key: const ValueKey('code-wrap'),
                      label: _wrap ? 'Scroll long lines' : 'Wrap long lines',
                      toggled: _wrap,
                      icon: Icons.wrap_text_rounded,
                      extent: widget.headerHeight,
                      onPressed: () => setState(() => _wrap = !_wrap),
                    ),
                    _CodeAction(
                      key: const ValueKey('code-copy'),
                      label: _copied ? 'Code copied' : 'Copy code',
                      icon: _copied
                          ? Icons.check_rounded
                          : Icons.content_copy_rounded,
                      extent: widget.headerHeight,
                      onPressed: _copy,
                    ),
                  ],
                ),
              ),
            ),
          ),
          ColoredBox(
            key: const ValueKey('code-body-surface'),
            color: widget.bodyBackground,
            child: _RhythmicCodeBody(
              beat: widget.beat,
              headerHeight: widget.headerHeight,
              child: body,
            ),
          ),
        ],
      ),
    );
  }
}

/// Lets source lines keep their compact leading, then returns the completed
/// surface to the running-text grid.
///
/// The small correction is shared above and below the body. Keeping it inside
/// the coloured surface prevents a variable external margin from appearing
/// between the code and the prose that follows.
final class _RhythmicCodeBody extends SingleChildRenderObjectWidget {
  final double beat;
  final double headerHeight;

  const _RhythmicCodeBody({
    required this.beat,
    required this.headerHeight,
    required super.child,
  });

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderRhythmicCodeBody(beat, headerHeight);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderRhythmicCodeBody renderObject,
  ) {
    renderObject
      ..beat = beat
      ..headerHeight = headerHeight;
  }
}

final class _RenderRhythmicCodeBody extends RenderShiftedBox {
  _RenderRhythmicCodeBody(this._beat, this._headerHeight, [RenderBox? child])
    : super(child);

  double _beat;
  double get beat => _beat;
  set beat(double value) {
    if (_beat == value) return;
    _beat = value;
    markNeedsLayout();
  }

  double _headerHeight;
  double get headerHeight => _headerHeight;
  set headerHeight(double value) {
    if (_headerHeight == value) return;
    _headerHeight = value;
    markNeedsLayout();
  }

  BoxConstraints _childConstraints(BoxConstraints constraints) =>
      constraints.copyWith(minHeight: 0, maxHeight: double.infinity);

  double _reconciledHeight(double childHeight) =>
      ((headerHeight + childHeight) / beat).ceil() * beat - headerHeight;

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final childSize = child?.getDryLayout(_childConstraints(constraints));
    if (childSize == null) return constraints.smallest;
    return constraints.constrain(
      Size(childSize.width, _reconciledHeight(childSize.height)),
    );
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }

    child.layout(_childConstraints(constraints), parentUsesSize: true);
    size = constraints.constrain(
      Size(child.size.width, _reconciledHeight(child.size.height)),
    );
    final childParentData = child.parentData! as BoxParentData;
    childParentData.offset = Offset(0, (size.height - child.size.height) / 2);
  }
}

final class _CodeAction extends StatelessWidget {
  final String label;
  final bool? toggled;
  final IconData icon;
  final double extent;
  final VoidCallback onPressed;

  const _CodeAction({
    super.key,
    required this.label,
    this.toggled,
    required this.icon,
    required this.extent,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        toggled: toggled,
        excludeSemantics: true,
        child: IconButton(
          onPressed: onPressed,
          constraints: BoxConstraints.tightFor(width: extent, height: extent),
          padding: EdgeInsets.zero,
          hoverColor: p.accentSoft,
          focusColor: p.accentSoft,
          highlightColor: Colors.transparent,
          icon: Icon(
            icon,
            size: 17,
            color: toggled == true ? p.accent : p.muted,
          ),
        ),
      ),
    );
  }
}
