import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:katex/katex.dart';

import '../render/reading_theme.dart';
import '../theme/library_chrome.dart';

/// An equation that belongs to the reading page rather than to a code panel.
///
/// Wide notation scrolls inside its own measure. The page therefore keeps its
/// column while matrices and derivations keep their authored structure. A
/// quiet hover action copies the TeX source; rendering failure leaves that
/// same source selectable instead of replacing the document with an error.
final class ReadableMathBlock extends StatefulWidget {
  final String source;
  final ReadingTheme theme;

  const ReadableMathBlock({
    super.key,
    required this.source,
    required this.theme,
  });

  @override
  State<ReadableMathBlock> createState() => _ReadableMathBlockState();
}

final class _ReadableMathBlockState extends State<ReadableMathBlock> {
  final _scroll = ScrollController();
  Timer? _copyFeedback;
  var _hovered = false;
  var _focused = false;
  var _copied = false;

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
    _copyFeedback?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final source = widget.source;
    final visibleAction = _hovered || _focused;
    final still = MediaQuery.disableAnimationsOf(context);
    final display = _DisplayEquation.parse(source);
    final equation = Semantics(
      container: true,
      label: 'Equation in TeX: $source',
      child: ExcludeSemantics(
        child: _NumberedEquation(
          display: display,
          source: source,
          theme: theme,
        ),
      ),
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: theme.baseline / 4),
            child: LayoutBuilder(
              builder: (context, constraints) => ScrollbarTheme(
                data: ScrollbarTheme.of(context).copyWith(
                  thickness: const WidgetStatePropertyAll(4),
                  radius: const Radius.circular(
                    LibraryChromeScale.componentRadius,
                  ),
                  thumbColor: WidgetStatePropertyAll(
                    theme.palette.muted.withValues(alpha: 0.55),
                  ),
                  trackVisibility: const WidgetStatePropertyAll(false),
                ),
                child: Scrollbar(
                  controller: _scroll,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    key: const ValueKey('math-horizontal-scroll'),
                    controller: _scroll,
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: constraints.maxWidth,
                      ),
                      child: Center(child: equation),
                    ),
                  ),
                ),
              ),
            ),
          ),
          PositionedDirectional(
            top: 0,
            end: 0,
            child: SelectionContainer.disabled(
              child: IgnorePointer(
                ignoring: !visibleAction,
                child: AnimatedOpacity(
                  key: const ValueKey('math-copy-visibility'),
                  opacity: visibleAction ? 1 : 0,
                  duration: still
                      ? Duration.zero
                      : const Duration(milliseconds: 120),
                  child: Focus(
                    onFocusChange: (focused) =>
                        setState(() => _focused = focused),
                    child: IconButton(
                      key: const ValueKey('math-copy'),
                      tooltip: _copied
                          ? 'Equation copied'
                          : 'Copy equation as TeX',
                      visualDensity: VisualDensity.compact,
                      iconSize: 16,
                      color: theme.palette.muted,
                      onPressed: _copy,
                      icon: Icon(
                        _copied
                            ? Icons.check_rounded
                            : Icons.content_copy_rounded,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The scholarly layout inside a display-math block.
///
/// The renderer currently accepts `\tag` but omits it from its painted tree.
/// Keeping this compatibility seam here prevents a silent loss of equation
/// numbers without teaching the Markdown adapter about a renderer limitation.
final class _NumberedEquation extends StatelessWidget {
  final _DisplayEquation display;
  final String source;
  final ReadingTheme theme;

  const _NumberedEquation({
    required this.display,
    required this.source,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final equation = Math(
      display.body,
      key: const ValueKey('math-equation-body'),
      displayMode: true,
      fontSize: theme.displayMathSize,
      color: theme.palette.ink,
      onError: (context, error) => Text(
        source,
        key: const ValueKey('math-error-source'),
        style: theme
            .inlineCodeFor(theme.body)
            .copyWith(color: theme.palette.muted),
      ),
    );
    final tag = display.tag;
    if (tag == null) return equation;

    // Reserve equal space on both sides so the equation remains centred on
    // the reading measure while its number sits at the scholarly right edge.
    // The reserve also keeps long notation and its tag from colliding; the
    // surrounding horizontal scroller makes the complete row reachable.
    final reserve = theme.baseline * 2.5;
    return Stack(
      alignment: Alignment.center,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: reserve),
          child: equation,
        ),
        PositionedDirectional(
          end: 0,
          child: KeyedSubtree(
            key: const ValueKey('math-equation-tag'),
            child: Math(
              tag.source,
              fontSize: theme.mathSizeFor(theme.body),
              color: theme.palette.ink,
              onError: (_, _) => Text(
                tag.fallback,
                style: theme.body.copyWith(color: theme.palette.ink),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

final class _DisplayEquation {
  final String body;
  final _EquationTag? tag;

  const _DisplayEquation(this.body, this.tag);

  /// Separates only a trailing top-level `\tag{...}` or `\tag*{...}`.
  ///
  /// Tags elsewhere remain with the source and are handled by the renderer's
  /// normal fallback. Scanning backwards keeps balanced braces inside a tag
  /// intact without pretending to be a general TeX parser.
  factory _DisplayEquation.parse(String source) {
    final end = source.trimRight();
    if (!end.endsWith('}')) return _DisplayEquation(source, null);

    var depth = 0;
    var open = -1;
    for (var index = end.length - 1; index >= 0; index--) {
      final character = end[index];
      if (_isEscaped(end, index)) continue;
      if (character == '}') {
        depth++;
      } else if (character == '{') {
        depth--;
        if (depth == 0) {
          open = index;
          break;
        }
      }
    }
    if (open < 0) return _DisplayEquation(source, null);

    final beforeArgument = end.substring(0, open).trimRight();
    final starred = beforeArgument.endsWith(r'\tag*');
    final command = starred ? r'\tag*' : r'\tag';
    if (!beforeArgument.endsWith(command)) {
      return _DisplayEquation(source, null);
    }
    final commandStart = beforeArgument.length - command.length;
    if (_isEscaped(beforeArgument, commandStart)) {
      return _DisplayEquation(source, null);
    }

    final body = beforeArgument.substring(0, commandStart).trimRight();
    if (body.isEmpty) return _DisplayEquation(source, null);
    final content = end.substring(open + 1, end.length - 1);
    final tagSource = starred ? content : '($content)';
    return _DisplayEquation(
      body,
      _EquationTag(source: tagSource, fallback: tagSource),
    );
  }
}

final class _EquationTag {
  final String source;
  final String fallback;

  const _EquationTag({required this.source, required this.fallback});
}

bool _isEscaped(String source, int index) {
  var slashes = 0;
  for (
    var cursor = index - 1;
    cursor >= 0 && source[cursor] == r'\';
    cursor--
  ) {
    slashes++;
  }
  return slashes.isOdd;
}

/// Typesets one equation on the surrounding text baseline.
///
/// The custom span keeps the TeX source in selection and semantics. A normal
/// [WidgetSpan] would flatten to U+FFFC, so copying a sentence would silently
/// lose the equation even though it remained visible.
InlineSpan readableMathSpan({
  required String source,
  required TextStyle style,
  required double fontSize,
  Color? background,
}) {
  final rendered = mathSpan(
    source,
    fontSize: fontSize,
    color: style.color,
    onError: (_) => TextSpan(
      text: source,
      style: style.copyWith(backgroundColor: background),
    ),
  );
  if (rendered is! WidgetSpan) return rendered;

  Widget child = ExcludeSemantics(child: rendered.child);
  if (background != null) child = ColoredBox(color: background, child: child);
  return MathInlineSpan(
    source: source,
    child: child,
    style: style,
    alignment: rendered.alignment,
    baseline: rendered.baseline,
  );
}

final class MathInlineSpan extends WidgetSpan {
  final String source;

  const MathInlineSpan({
    required this.source,
    required super.child,
    required super.alignment,
    required super.baseline,
    required super.style,
  });

  @override
  void computeToPlainText(
    StringBuffer buffer, {
    bool includeSemanticsLabels = true,
    bool includePlaceholders = true,
  }) {
    buffer.write(source);
  }

  @override
  void computeSemanticsInformation(
    List<InlineSpanSemanticsInformation> collector, {
    ui.Locale? inheritedLocale,
    bool inheritedSpellOut = false,
  }) {
    collector.add(InlineSpanSemanticsInformation(source));
  }
}
