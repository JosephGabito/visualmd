import '../../domain/reading/content/inline.dart';
import '../../presentation/theme/widow_binding.dart';

/// A source-offset index over text-only inline structure.
///
/// The domain keeps nested marks because they are meaning. A large paragraph
/// renderer needs the inverse view as well: locate the few leaves intersecting
/// one source range without walking every styled run before it. This index is
/// built once per block revision and reconstructs only the intersecting
/// structure, preserving container boundaries and authored text.
final class InlineRangeIndex {
  final List<_InlineLeaf> _leaves;
  final String source;

  InlineRangeIndex(List<Inline> content) : this._(_build(content));

  InlineRangeIndex._(_InlineIndexBuild build)
    : _leaves = List.unmodifiable(build.leaves),
      source = build.source;

  int get length => source.length;

  /// Whether [content] can be represented entirely as styled text ranges.
  ///
  /// Widgets, mathematics and footnote controls own geometry or semantics
  /// beyond their text and deliberately remain on the eager paragraph path.
  static bool supports(List<Inline> content) => content.every(_supportsRun);

  /// Visible UTF-16 length without joining or allocating the visible string.
  static int textLength(List<Inline> content) =>
      content.fold(0, (total, run) => total + _textLengthOf(run));

  /// Reconstructs the exact inline tree intersecting [start] .. [end].
  ///
  /// Seeking the first leaf is logarithmic. Work after that is proportional
  /// only to leaves which contribute visible text to the requested range.
  List<Inline> slice(int start, int end) {
    RangeError.checkValueInInterval(start, 0, source.length, 'start');
    RangeError.checkValueInInterval(end, start, source.length, 'end');
    if (start == end || _leaves.isEmpty) return const [];

    var low = 0;
    var high = _leaves.length;
    while (low < high) {
      final middle = low + ((high - low) >> 1);
      if (_leaves[middle].end <= start) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }

    final root = <Inline>[];
    final frames = <_ContainerFrame>[];
    var previousPath = const <_InlineContainer>[];
    for (var index = low; index < _leaves.length; index++) {
      final leaf = _leaves[index];
      if (leaf.start >= end) break;
      final localStart = (start - leaf.start).clamp(0, leaf.text.length);
      final localEnd = (end - leaf.start).clamp(0, leaf.text.length);
      if (localStart >= localEnd) continue;

      var common = 0;
      while (common < previousPath.length &&
          common < leaf.path.length &&
          identical(previousPath[common], leaf.path[common])) {
        common++;
      }
      _closeFrames(frames, root, common);
      for (final container in leaf.path.skip(common)) {
        frames.add(_ContainerFrame(container));
      }

      final sliced = leaf.slice(localStart, localEnd);
      if (frames.isEmpty) {
        root.add(sliced);
      } else {
        frames.last.children.add(sliced);
      }
      previousPath = leaf.path;
    }
    _closeFrames(frames, root, 0);
    return List.unmodifiable(root);
  }

  /// The final authored space eligible for widow binding in this structure.
  ///
  /// Links and code are deliberate endings in the eager composer, so a range
  /// renderer must leave those endings exact as well. Ordinary nested marks
  /// remain eligible.
  int? get widowOffset {
    if (_leaves.isEmpty) return null;
    final last = _leaves.last;
    if (last.kind != _InlineLeafKind.text ||
        last.path.any((container) => container is _LinkContainer)) {
      return null;
    }
    return WidowBinding.bindingOffset(source);
  }

  static _InlineIndexBuild _build(List<Inline> content) {
    if (!supports(content)) {
      throw ArgumentError.value(
        content,
        'content',
        'Inline widgets and control runs cannot be range indexed',
      );
    }
    final leaves = <_InlineLeaf>[];
    final source = StringBuffer();
    var offset = 0;

    void visit(Inline run, List<_InlineContainer> path) {
      switch (run) {
        case TextRun(:final text):
          if (text.isEmpty) return;
          leaves.add(
            _InlineLeaf(
              start: offset,
              text: text,
              kind: _InlineLeafKind.text,
              path: List.unmodifiable(path),
            ),
          );
          source.write(text);
          offset += text.length;
        case CodeRun(:final text):
          if (text.isEmpty) return;
          leaves.add(
            _InlineLeaf(
              start: offset,
              text: text,
              kind: _InlineLeafKind.code,
              path: List.unmodifiable(path),
            ),
          );
          source.write(text);
          offset += text.length;
        case LineBreakRun():
          leaves.add(
            _InlineLeaf(
              start: offset,
              text: '\n',
              kind: _InlineLeafKind.lineBreak,
              path: List.unmodifiable(path),
            ),
          );
          source.write('\n');
          offset++;
        case MarkedRun(:final mark, :final children):
          final container = _MarkContainer(mark);
          for (final child in children) {
            visit(child, [...path, container]);
          }
        case LinkRun(:final href, :final title, :final children):
          final container = _LinkContainer(href: href, title: title);
          for (final child in children) {
            visit(child, [...path, container]);
          }
        case MathRun() ||
            FootnoteReferenceRun() ||
            FootnoteBackReferenceRun() ||
            ImageRun():
          throw StateError('Unsupported inline content escaped validation.');
      }
    }

    for (final run in content) {
      visit(run, const []);
    }
    return _InlineIndexBuild(leaves, source.toString());
  }

  static bool _supportsRun(Inline run) => switch (run) {
    TextRun() || CodeRun() || LineBreakRun() => true,
    MarkedRun(:final children) ||
    LinkRun(:final children) => children.every(_supportsRun),
    MathRun() ||
    FootnoteReferenceRun() ||
    FootnoteBackReferenceRun() ||
    ImageRun() => false,
  };

  static int _textLengthOf(Inline run) => switch (run) {
    TextRun(:final text) || CodeRun(:final text) => text.length,
    LineBreakRun() => 1,
    MarkedRun(:final children) || LinkRun(:final children) => children.fold(
      0,
      (total, child) => total + _textLengthOf(child),
    ),
    MathRun(:final source) => source.length,
    FootnoteReferenceRun(:final text) ||
    FootnoteBackReferenceRun(:final text) ||
    ImageRun(:final text) => text.length,
  };

  static void _closeFrames(
    List<_ContainerFrame> frames,
    List<Inline> root,
    int length,
  ) {
    while (frames.length > length) {
      final frame = frames.removeLast();
      final wrapped = frame.container.wrap(List.unmodifiable(frame.children));
      if (frames.isEmpty) {
        root.add(wrapped);
      } else {
        frames.last.children.add(wrapped);
      }
    }
  }
}

final class _InlineIndexBuild {
  final List<_InlineLeaf> leaves;
  final String source;

  const _InlineIndexBuild(this.leaves, this.source);
}

enum _InlineLeafKind { text, code, lineBreak }

final class _InlineLeaf {
  final int start;
  final String text;
  final _InlineLeafKind kind;
  final List<_InlineContainer> path;

  const _InlineLeaf({
    required this.start,
    required this.text,
    required this.kind,
    required this.path,
  });

  int get end => start + text.length;

  Inline slice(int start, int end) {
    final value = text.substring(start, end);
    return switch (kind) {
      _InlineLeafKind.text => TextRun(value),
      _InlineLeafKind.code => CodeRun(value),
      _InlineLeafKind.lineBreak => const LineBreakRun(),
    };
  }
}

sealed class _InlineContainer {
  const _InlineContainer();

  Inline wrap(List<Inline> children);
}

final class _MarkContainer extends _InlineContainer {
  final InlineMark mark;

  const _MarkContainer(this.mark);

  @override
  Inline wrap(List<Inline> children) => MarkedRun(mark, children);
}

final class _LinkContainer extends _InlineContainer {
  final String href;
  final String? title;

  const _LinkContainer({required this.href, required this.title});

  @override
  Inline wrap(List<Inline> children) =>
      LinkRun(href: href, title: title, children: children);
}

final class _ContainerFrame {
  final _InlineContainer container;
  final List<Inline> children = [];

  _ContainerFrame(this.container);
}
