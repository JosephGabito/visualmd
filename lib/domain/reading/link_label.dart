import 'link_label_case_folding.g.dart';

/// The identity rule shared by a reference definition and every link that
/// names it.
///
/// CommonMark ignores leading and trailing whitespace, collapses internal
/// formatting whitespace, and compares labels by Unicode case folding. The
/// generated map is deliberately synchronized with package:markdown, because
/// the framework-free outline and the infrastructure page parser must resolve
/// the same heading to the same reading text.
abstract final class LinkLabel {
  static final _whitespace = RegExp(r'[ \n\r\t]+');

  static String normalize(String source) {
    var normalized = source.trim().replaceAll(_whitespace, ' ');
    for (var index = 0; index < normalized.length; index++) {
      final folded = linkLabelCaseFolding[normalized[index]];
      if (folded != null) {
        normalized = normalized.replaceRange(index, index + 1, folded);
      }
    }
    return normalized;
  }
}
