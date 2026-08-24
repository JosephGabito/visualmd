import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/reading/content/block.dart';
import '../theme/reading_measure.dart';
import '../../presentation/theme/reading_scale.dart';
import '../../presentation/theme/theme_palette.dart';
import '../theme/font_metrics.dart';
import '../theme/library_theme.dart';

/// Every text style and gap the page is set with, derived once from the
/// palette, the faces and the scale.
///
/// This is our own vocabulary rather than a rendering package's: the reader
/// needs distinctions a general-purpose style sheet does not have — a width
/// for prose and a wider one for code, gaps expressed in lines, figures that
/// differ between running text and tables.
@immutable
final class ReadingTheme {
  final ReadingScale scale;
  final LibraryPalette palette;
  final TextScaler textScaler;

  /// The line height actually used, worked out for the face in hand. Every
  /// gap on the page is cut from it, so the rhythm follows the face rather
  /// than a constant.
  final double leading;

  /// The body's font size as it is actually set, after the face's x-height
  /// has been accounted for. The beat is measured from this rather than from
  /// the size that was asked for — otherwise the grid is counted in a unit
  /// the page never uses.
  final double renderedBase;

  final TextStyle body;
  final TextStyle code;
  final TextStyle quote;
  final TextStyle marker;
  final TextStyle tableHead;
  final TextStyle tableBody;
  final List<TextStyle> headings;

  const ReadingTheme._({
    required this.scale,
    required this.palette,
    required this.textScaler,
    required this.leading,
    required this.renderedBase,
    required this.body,
    required this.code,
    required this.quote,
    required this.marker,
    required this.tableHead,
    required this.tableBody,
    required this.headings,
  });

  factory ReadingTheme.of(BuildContext context, ReadingScale scale) {
    final p = context.palette;
    final type = context.type;
    final textScaler = MediaQuery.textScalerOf(context);
    final dark = Theme.of(context).brightness == Brightness.dark;

    // Light type on a dark ground optically thickens and closes up, so it is
    // tracked a hair looser than the same text on paper. Nobody sees this;
    // they only see that the dark theme reads as easily as the light one.
    final tracking = dark ? scale.base * 0.008 : 0.0;

    // Old-style figures have ascenders and descenders like lowercase letters,
    // so a number in a sentence sits in the line rather than standing up out
    // of it. Tables want the opposite: figures that line up in a column.
    const prose = [FontFeature.oldstyleFigures()];
    const tabular = [FontFeature.liningFigures(), FontFeature.tabularFigures()];

    final leading = FontMetrics.leadingFor(type.families.serif, scale.leading);
    final body = type
        .serif(color: p.ink, size: scale.base, height: leading)
        .copyWith(fontFeatures: prose, letterSpacing: tracking);

    final renderedBase = textScaler.scale(body.fontSize ?? scale.base);
    final unit = renderedBase * leading;

    // Tone as a third cue, under size and weight.
    //
    // A heading is told from the text by how large it is and how bold; a
    // little more or less ink says the same thing again quietly, and gives
    // the page depth. The scale runs h1 darkest, down through the body, to
    // h5 and h6 sitting just back from it — small headings should recede
    // rather than compete with the sentence beneath them.
    //
    // It is written as a distance from the running text towards ink or away
    // from it, never as a lightness: on a dark page, "more emphatic" means
    // lighter, and the same numbers have to work both ways round.
    final extreme = dark ? const Color(0xFFFFFFFF) : const Color(0xFF000000);
    Color emphasised(double towards) => Color.lerp(p.ink, extreme, towards)!;
    Color receded(double towards) => Color.lerp(p.ink, p.muted, towards)!;

    // The body itself is never dimmed: contrast is what legibility rests on,
    // and a paragraph is the thing being read.
    const emphasis = [0.26, 0.16, 0.07, 0.0];
    const recession = 0.22;

    // Display type closes up as it grows. These are deliberately not snapped
    // to the body beat: a heading's lines belong to one another, not to the
    // running-text grid. DocumentView reconciles the completed heading block
    // with that grid after Flutter has shaped every line and fallback glyph.
    const headingLeading = [1.14, 1.18, 1.24, 1.30, 1.40];

    TextStyle heading(int level) {
      final safeLevel = level.clamp(1, 6);
      final drawn = type.serif(
        color: safeLevel <= 4
            ? emphasised(emphasis[safeLevel - 1])
            : receded(recession),
        size: scale.heading(safeLevel),
        // One weight for every heading. Size already says which level this
        // is; a second, quieter bold would be the same signal said twice.
        weight: FontWeight.w700,
      );
      return drawn.copyWith(
        height: safeLevel == 6 ? leading : headingLeading[safeLevel - 1],
        // Tighter as the size grows; at body size a heading leans on weight
        // and a little extra tracking instead.
        letterSpacing:
            (safeLevel <= 3 ? -0.3 : (safeLevel == 6 ? 0.2 : 0)) + tracking,
      );
    }

    return ReadingTheme._(
      scale: scale,
      palette: p,
      textScaler: textScaler,
      leading: leading,
      renderedBase: renderedBase,
      body: body,
      code: _onBeat(type.mono(color: p.ink, size: scale.code), unit, textScaler)
          .copyWith(
            letterSpacing: tracking,
            // Zero and capital O are the pair a reader of technical documents
            // most often has to tell apart, and guessing is how a command gets
            // typed wrong.
            fontFeatures: const [FontFeature.slashedZero()],
          ),
      quote: body.copyWith(color: p.muted),
      marker: body.copyWith(color: p.muted),
      tableHead: _onBeat(
        type.serif(
          color: p.ink,
          size: scale.tableText,
          weight: FontWeight.w600,
        ),
        unit,
        textScaler,
      ).copyWith(fontFeatures: tabular, letterSpacing: tracking),
      tableBody: _onBeat(
        type.serif(color: p.ink, size: scale.tableText),
        unit,
        textScaler,
      ).copyWith(fontFeatures: tabular, letterSpacing: tracking),
      headings: [for (var level = 1; level <= 6; level++) heading(level)],
    );
  }

  TextStyle heading(int level) => headings[level.clamp(1, 6) - 1];

  /// The same page, one shade back, for matter inside a quotation. The rule
  /// down its left already says it is quoted; the colour is the second and
  /// last signal.
  static ReadingTheme quoting(ReadingTheme theme) => ReadingTheme._(
    scale: theme.scale,
    palette: theme.palette,
    textScaler: theme.textScaler,
    leading: theme.leading,
    renderedBase: theme.renderedBase,
    body: theme.quote,
    code: theme.code,
    quote: theme.quote,
    marker: theme.marker,
    tableHead: theme.tableHead,
    tableBody: theme.tableBody,
    headings: theme.headings,
  );

  /// A link keeps the typographic role it appears in. A link in a heading is
  /// still a heading; colour and underline say only that it can be followed.
  TextStyle linkFor(TextStyle base) => base.copyWith(
    color: palette.accent,
    decoration: TextDecoration.underline,
    decorationColor: palette.accent.withValues(alpha: 0.4),
    decorationThickness: 1,
  );

  /// Inline code keeps the x-height of the surrounding role, a shade smaller,
  /// instead of collapsing every heading and table run to body-code size.
  TextStyle inlineCodeFor(TextStyle base) {
    final bodySize = body.fontSize ?? scale.base;
    final baseSize = base.fontSize ?? bodySize;
    return code.copyWith(
      fontSize: (code.fontSize ?? scale.code) * baseSize / bodySize,
      color: _contrastSafeAccent(palette),
      // A decoration is ink, not geometry: this identifies a technical
      // reference without padding the run or moving the paragraph off its
      // beat. Its muted stroke supports the coloured text without repeating
      // the same strong signal.
      backgroundColor: null,
      decoration: TextDecoration.underline,
      decorationColor: palette.muted.withValues(alpha: 0.4),
      // Flutter defines this as a multiplier of the face's own underline.
      decorationThickness: 1.25,
      height: base.height,
    );
  }

  /// The width prose is set to: the measure, or the room available if that
  /// is narrower. Everything on the page lines up against this.
  double proseWidth(double available) => math.min(
    ReadingMeasure.columnWidth(body, scale.measure, scaler: textScaler),
    available,
  );

  /// The width code and tables may take. They are not bound by the measure —
  /// a line of code is as long as it is — but they still belong to the page.
  double wideWidth(double available) =>
      math.min(available, proseWidth(available) * 1.35);

  /// The inset inside either side of a table cell, in the rendered body em.
  double get tableCellHorizontalPadding => em * 0.65;

  /// The intrinsic width a table cell contributes to its column.
  ///
  /// A short atomic value keeps its complete natural width: `MAE1` needs four
  /// characters, not a prose line. Longer content stops growing at the lower
  /// comfortable reading measure and wraps there. The widest contribution in
  /// a column becomes that column's minimum.
  double minimumTableCellWidth(String text, TextStyle style) {
    final natural = ReadingMeasure.widthOf(text, style, scaler: textScaler);
    final readable = ReadingMeasure.columnWidth(
      style,
      ReadingScale.minimumReadableMeasure,
      scaler: textScaler,
    );
    return math.min(natural, readable) + tableCellHorizontalPadding * 2;
  }

  /// The baseline: one line of body text, and the beat everything on the
  /// page is measured in.
  ///
  /// The rule this page keeps is Bringhurst's — the vertical space taken by
  /// any departure from the running text must come to a whole number of
  /// these, so the text returns afterwards on the beat rather than a few
  /// pixels off it. A page where every line lands on the same rhythm is
  /// quieter to read than one where each block drifts by a fraction.
  double get baseline => renderedBase * leading;

  /// One line of body text. The same measurement as [baseline]; the name is
  /// kept for reading about text rather than about the grid.
  double get line => baseline;

  /// Gives [style] a line height of exactly one beat, whatever size the face
  /// turned out to need.
  static TextStyle _onBeat(TextStyle style, double unit, TextScaler scaler) =>
      style.copyWith(height: unit / scaler.scale(style.fontSize ?? unit));

  /// One em in the face and accessibility size actually on the page.
  double get em => renderedBase;

  /// The traditional paragraph indent: one rendered em.
  double get indent => em;

  /// A strut holds every line box to the same height whatever is set inside
  /// it. Without one, a line carrying a code span or a smaller run grows to
  /// fit and pushes itself off the beat — which is how a grid ends up being
  /// something a page merely aspires to.
  StrutStyle strutFor(TextStyle style) =>
      StrutStyle.fromTextStyle(style, forceStrutHeight: true);

  /// Rounds a height up to the next whole beat.
  double snap(double height) => (height / baseline).ceil() * baseline;

  /// The gap between ordinary blocks: one beat — a blank line, exactly.
  double get blockGap => baseline;

  /// The only external vertical space between document blocks.
  ///
  /// A sequence spends this *after* [current], never before [next]. That gives
  /// every gap one owner and lets the same top-down rule work in the document,
  /// quotations and list items. The pair still matters: headings bind to what
  /// follows with half a beat; spaced paragraphs use that same quiet interval
  /// rather than skipping a wasteful full line; indented paragraphs form a
  /// solid column. The final block leaves no trailing space.
  double spaceAfter(Block current, Block? next) {
    if (next == null) return 0;
    if (current is HeadingBlock) return baseline / 2;
    if (current is ParagraphBlock && next is ParagraphBlock) {
      return switch (scale.marking) {
        ParagraphMarking.spaced => baseline / 2,
        ParagraphMarking.indented => 0,
      };
    }
    return blockGap;
  }
}

/// The strongest theme colour that still meets ordinary-text contrast.
///
/// Accent is the intended signal. When a theme's accent is too faint against
/// its paper, binary search finds the smallest move toward its already-legible
/// ink that reaches WCAG's 4.5:1 threshold.
Color _contrastSafeAccent(LibraryPalette palette) {
  final accent = palette.accent;
  if (ThemePalette.contrastRatio(accent, palette.paper) >=
      ThemePalette.minimumTextContrast) {
    return accent;
  }

  var tooFaint = 0.0;
  var sufficient = 1.0;
  for (var i = 0; i < 12; i++) {
    final middle = (tooFaint + sufficient) / 2;
    final candidate = Color.lerp(accent, palette.ink, middle)!;
    if (ThemePalette.contrastRatio(candidate, palette.paper) >=
        ThemePalette.minimumTextContrast) {
      sufficient = middle;
    } else {
      tooFaint = middle;
    }
  }
  return Color.lerp(accent, palette.ink, sufficient)!;
}
