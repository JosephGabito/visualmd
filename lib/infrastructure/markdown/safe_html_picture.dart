import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html;

import '../../domain/reading/content/inline.dart';

/// Recognises the narrow `picture` contract that has meaning in this reader.
///
/// Visual MD is not a browser: it does not evaluate CSS media queries or the
/// complete `srcset` selection algorithm. GitHub's light/dark authoring form
/// is useful on a themed reading page, however, and can be reduced to ordered
/// domain candidates without carrying a DOM node or an arbitrary attribute
/// across the infrastructure boundary.
abstract final class SafeHtmlPicture {
  static final _pictureShaped = RegExp(
    r'^\s*<\s*/?\s*picture(?:\s|/?>)',
    caseSensitive: false,
  );
  static final _openingPicture = RegExp(
    r'^\s*<\s*picture(?:\s|>)',
    caseSensitive: false,
  );
  static final _closingPicture = RegExp(
    r'<\s*/\s*picture\s*>\s*$',
    caseSensitive: false,
  );
  static final _colorScheme = RegExp(
    r'^\(\s*prefers-color-scheme\s*:\s*(light|dark)\s*\)$',
    caseSensitive: false,
  );

  static bool claims(String source) => _pictureShaped.hasMatch(source);

  /// Returns one fallback-backed image, or null when the container is not the
  /// complete, accessible picture shape Visual MD supports.
  static ImageRun? parse(String source) {
    if (!claims(source) ||
        !_openingPicture.hasMatch(source) ||
        !_closingPicture.hasMatch(source)) {
      return null;
    }
    try {
      final fragment = html.parseFragment(source);
      final roots = fragment.nodes.whereType<dom.Element>().toList();
      if (roots.length != 1 || _name(roots.single) != 'picture') return null;
      if (fragment.nodes.any(
        (node) => node is dom.Text && node.data.trim().isNotEmpty,
      )) {
        return null;
      }

      final picture = roots.single;
      if (picture.nodes.any(
        (node) => node is dom.Text && node.data.trim().isNotEmpty,
      )) {
        return null;
      }
      final children = picture.children;
      if (children.isEmpty ||
          children.any((child) {
            final name = _name(child);
            return name != 'source' && name != 'img';
          })) {
        return null;
      }

      final images = children.where((child) => _name(child) == 'img').toList();
      if (images.length != 1 || !identical(children.last, images.single)) {
        return null;
      }
      final image = images.single;
      final fallback = image.attributes['src']?.trim();
      if (fallback == null ||
          fallback.isEmpty ||
          !image.attributes.containsKey('alt')) {
        return null;
      }

      final candidates = <ThemedImageSource>[];
      for (final child in children.take(children.length - 1)) {
        // A MIME condition is meaningful only when the runtime can prove that
        // it supports the declared format. Visual MD deliberately does not
        // reproduce browser content negotiation, so the safe choice is to
        // leave that candidate unresolved and continue toward the fallback.
        if (child.attributes.containsKey('type')) continue;
        final match = _colorScheme.firstMatch(
          child.attributes['media']?.trim() ?? '',
        );
        final candidate = _singleCandidate(child.attributes['srcset']);
        if (match == null || candidate == null) continue;
        candidates.add(
          ThemedImageSource(
            scheme: match[1]!.toLowerCase() == 'dark'
                ? ImageColorScheme.dark
                : ImageColorScheme.light,
            source: candidate,
          ),
        );
      }

      return ImageRun(
        source: fallback,
        title: image.attributes['title'],
        alt: image.attributes['alt'] ?? '',
        themedSources: candidates,
      );
    } on Object {
      return null;
    }
  }

  /// The GitHub form contributes one URL per colour scheme. Commas,
  /// whitespace, density descriptors and width descriptors belong to the
  /// browser's much larger responsive-image algorithm and are not guessed.
  static String? _singleCandidate(String? srcset) {
    final candidate = srcset?.trim();
    if (candidate == null ||
        candidate.isEmpty ||
        candidate.contains(',') ||
        RegExp(r'\s').hasMatch(candidate)) {
      return null;
    }
    return candidate;
  }

  static String _name(dom.Element element) =>
      (element.localName ?? '').toLowerCase();
}
