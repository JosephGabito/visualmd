import 'package:csslib/parser.dart' as css;
import 'package:csslib/visitor.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;

/// Turns a renderer's CSS-styled SVG into one inert, self-contained image.
///
/// Browsers apply the stylesheet inside Mermaid's SVG. Flutter's SVG painter
/// deliberately implements SVG painting rather than a browser CSS cascade, so
/// the same otherwise-valid artifact loses its fills and strokes on every
/// Flutter target. Resolving the cascade once at the adapter boundary gives
/// web and native the same presentation attributes without introducing a
/// WebView, scripts, or target-specific rendering behavior.
String inlineSvgStyles(String svg) {
  final document = html.parse(svg);
  final root = document.querySelector('svg');
  if (root == null) return svg;

  final winners = <Element, Map<String, _CascadedValue>>{};
  var sourceOrder = 0;

  for (final element in document.querySelectorAll('*')) {
    final inlineStyle = element.attributes['style'];
    if (inlineStyle == null || inlineStyle.trim().isEmpty) continue;
    _mergeDeclarations(
      winners.putIfAbsent(element, () => {}),
      _parseDeclarations(inlineStyle),
      specificity: 1000,
      sourceOrder: sourceOrder++,
    );
  }

  for (final styleElement in document.querySelectorAll('style')) {
    final stylesheet = css.parse(styleElement.text);
    for (final topLevel in stylesheet.topLevels) {
      if (topLevel is! RuleSet || topLevel.selectorGroup == null) continue;
      final declarations = topLevel.declarationGroup.declarations
          .whereType<Declaration>()
          .map(_declarationFromCss)
          .toList(growable: false);

      for (final selector in topLevel.selectorGroup!.selectors) {
        final selectorText = _printCss(selector);
        List<Element> matches;
        try {
          matches = document.querySelectorAll(selectorText);
        } on FormatException {
          // A future Mermaid renderer may emit a selector understood by a
          // browser but not package:html. Leaving that one rule unresolved is
          // safer than rejecting a diagram whose geometry is otherwise valid.
          continue;
        }
        final specificity = _specificity(selector);
        for (final element in matches) {
          _mergeDeclarations(
            winners.putIfAbsent(element, () => {}),
            declarations,
            specificity: specificity,
            sourceOrder: sourceOrder,
          );
        }
        sourceOrder++;
      }
    }
    styleElement.remove();
  }

  for (final entry in winners.entries) {
    final declarations = entry.value.entries.toList(growable: false)
      ..sort((a, b) => a.value.sourceOrder.compareTo(b.value.sourceOrder));
    for (final declaration in declarations) {
      entry.key.attributes[declaration.key] = declaration.value.value;
    }
    entry.key.attributes.remove('style');
  }

  return root.outerHtml;
}

void _mergeDeclarations(
  Map<String, _CascadedValue> target,
  Iterable<_CssDeclaration> declarations, {
  required int specificity,
  required int sourceOrder,
}) {
  for (final declaration in declarations) {
    if (!_svgPresentationProperties.contains(declaration.property)) continue;

    final candidate = _CascadedValue(
      value: declaration.value,
      important: declaration.important,
      specificity: specificity,
      sourceOrder: sourceOrder,
    );
    final current = target[declaration.property];
    if (current == null || candidate.outranks(current)) {
      target[declaration.property] = candidate;
    }
  }
}

/// CSS properties whose values have direct, inert SVG presentation-attribute
/// equivalents understood by Flutter's painter.
///
/// Merman has already sanitized the SVG, but this adapter becomes the owner of
/// the rewritten artifact. An allowlist keeps browser-layout declarations and
/// future URL-bearing CSS from becoming arbitrary XML attributes while
/// retaining every paint primitive a diagram can legitimately need.
const _svgPresentationProperties = <String>{
  'alignment-baseline',
  'clip-path',
  'color',
  'display',
  'dominant-baseline',
  'fill',
  'fill-opacity',
  'fill-rule',
  'filter',
  'flood-color',
  'flood-opacity',
  'font-family',
  'font-size',
  'font-style',
  'font-weight',
  'marker-end',
  'marker-mid',
  'marker-start',
  'mask',
  'opacity',
  'paint-order',
  'stop-color',
  'stop-opacity',
  'stroke',
  'stroke-dasharray',
  'stroke-dashoffset',
  'stroke-linecap',
  'stroke-linejoin',
  'stroke-miterlimit',
  'stroke-opacity',
  'stroke-width',
  'text-anchor',
  'vector-effect',
  'visibility',
};

Iterable<_CssDeclaration> _parseDeclarations(String source) {
  final stylesheet = css.parse('svg{$source}');
  final rule = stylesheet.topLevels.whereType<RuleSet>().firstOrNull;
  if (rule == null) return const [];
  return rule.declarationGroup.declarations.whereType<Declaration>().map(
    _declarationFromCss,
  );
}

_CssDeclaration _declarationFromCss(Declaration declaration) => _CssDeclaration(
  property: declaration.property,
  value: _printCss(declaration.expression!),
  important: declaration.important,
);

String _printCss(TreeNode node) {
  final printer = CssPrinter();
  node.visit(printer);
  return printer.toString();
}

int _specificity(Selector selector) {
  var score = 0;
  for (final sequence in selector.simpleSelectorSequences) {
    final simple = sequence.simpleSelector;
    score += switch (simple) {
      IdSelector() => 100,
      ClassSelector() || AttributeSelector() || PseudoClassSelector() => 10,
      ElementSelector() when !simple.isWildcard => 1,
      PseudoElementSelector() => 1,
      NegationSelector(:final negationArg?) => _specificityOfSimple(
        negationArg,
      ),
      _ => 0,
    };
  }
  return score;
}

int _specificityOfSimple(SimpleSelector selector) => switch (selector) {
  IdSelector() => 100,
  ClassSelector() || AttributeSelector() || PseudoClassSelector() => 10,
  ElementSelector() when !selector.isWildcard => 1,
  PseudoElementSelector() => 1,
  _ => 0,
};

final class _CssDeclaration {
  const _CssDeclaration({
    required this.property,
    required this.value,
    required this.important,
  });

  final String property;
  final String value;
  final bool important;
}

final class _CascadedValue {
  const _CascadedValue({
    required this.value,
    required this.important,
    required this.specificity,
    required this.sourceOrder,
  });

  final String value;
  final bool important;
  final int specificity;
  final int sourceOrder;

  bool outranks(_CascadedValue other) {
    if (important != other.important) return important;
    if (specificity != other.specificity) {
      return specificity > other.specificity;
    }
    return sourceOrder >= other.sourceOrder;
  }
}
