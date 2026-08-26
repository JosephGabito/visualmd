/// The proportions of the reading column: one size, one leading, one measure,
/// and everything else derived from them.
///
/// Numbers here are not taste. The measure is the number of characters on a
/// line, which decides how reliably the eye finds the next one; the leading
/// follows the measure; the spacing follows the leading. Change [base] and the
/// whole page stays in proportion.
final class ReadingScale {
  /// Body size in logical pixels.
  final double base;

  /// Line height as a multiple of [base].
  final double leading;

  /// Characters per line the column aims for. A 55-character screen line was
  /// judged easiest in Dyson and Kipping's study; WCAG's ceiling is 80.
  final double measure;

  /// The fewest average characters in a comfortable reading line.
  ///
  /// Dyson and Kipping found 55-character screen lines easiest to read; their
  /// 25-character condition was slower. The target remains 66, while 55 is
  /// the lower measure used when a component must protect readable text.
  static const double minimumReadableMeasure = 55;

  /// How one paragraph is told from the next.
  final ParagraphMarking marking;

  const ReadingScale({
    this.base = 18,
    this.leading = 1.65,
    this.measure = 66,
    this.marking = ParagraphMarking.spaced,
  });

  static const comfortable = ReadingScale();

  /// The body sizes a reader can choose between. Steps of roughly one
  /// logical pixel at the low end and two at the high end: each is a visible
  /// change without being a jump.
  static const sizes = [15.0, 16.0, 17.0, 18.0, 19.0, 20.0, 22.0, 24.0];

  /// The scale one step larger, or this one at the top of the range.
  ReadingScale larger() => _step(1);

  /// The scale one step smaller, or this one at the bottom of the range.
  ReadingScale smaller() => _step(-1);

  ReadingScale _step(int by) {
    final nearest = sizes.indexOf(
      sizes.reduce((a, b) => (a - base).abs() <= (b - base).abs() ? a : b),
    );
    return copyWith(base: sizes[(nearest + by).clamp(0, sizes.length - 1)]);
  }

  /// Reads back the reader's choice; anything unfamiliar falls back to the
  /// comfortable default rather than refusing to open.
  static ReadingScale fromStoredBase(String? stored) {
    final size = double.tryParse(stored ?? '');
    if (size == null || !sizes.contains(size)) return comfortable;
    return comfortable.copyWith(base: size);
  }

  String get storedBase => base.toString();

  /// Reads back how the reader asked for paragraphs to be marked.
  static ParagraphMarking markingFromStored(String? stored) => switch (stored) {
    'indented' => ParagraphMarking.indented,
    _ => ParagraphMarking.spaced,
  };

  String get storedMarking => marking.name;

  /// Heading sizes, as multiples of [base]. No heading is smaller than the
  /// text it heads — a heading that shrinks below body size is not a
  /// hierarchy — and each step is a visible 11–19% larger than the one below.
  static const _headingRatio = [2.05, 1.72, 1.44, 1.27, 1.11, 1.0];

  double heading(int level) => base * _headingRatio[level.clamp(1, 6) - 1];

  /// The first-line indent of an indented paragraph: an em, near enough —
  /// the traditional quad, proportional to the type so it stays right at any
  /// size.
  double get indent => base;

  // The gaps between blocks are not here. They have to be measured in the
  // size the page is actually set at, which is known only once a face has
  // been chosen and its x-height accounted for — so `ReadingTheme` owns the
  // beat and everything cut from it. Two descriptions of one thing in two
  // rings is how they drift apart.

  /// The smallest code size offered, in logical pixels.
  ///
  /// A reader may reduce prose to 15 px. Letting dense source follow it all
  /// the way down would make punctuation and similar glyphs needlessly hard
  /// to distinguish, so code stops at this independently legible floor.
  static const double minimumCodeSize = 13;

  /// Code is three logical pixels smaller than prose.
  ///
  /// This is an absolute typographic step, not a percentage. At the
  /// comfortable 18 px reading size, fenced source is therefore 15 px.
  double get code {
    final reduced = base - 3;
    return reduced < minimumCodeSize ? minimumCodeSize : reduced;
  }

  /// The complete height of one source line, in logical pixels.
  ///
  /// Seven pixels of leading keep punctuation distinct without giving dense
  /// reference material the open texture of running prose. At the comfortable
  /// scale this is a 15 px face on a 22 px line.
  double get codeLineHeight => code + 7;

  /// Inline code is one logical pixel smaller than the role around it.
  ///
  /// A code span remains part of a sentence, so it only steps back once. A
  /// fenced block is a separate reference surface and uses the stronger
  /// three-pixel reduction above. Both stop at the same legibility floor.
  double inlineCodeSize(double surroundingSize) {
    final reduced = surroundingSize - 1;
    return reduced < minimumCodeSize ? minimumCodeSize : reduced;
  }

  /// Footnotes sit two logical pixels below the running text.
  ///
  /// This is an absolute step rather than a ratio: the note remains visibly
  /// subordinate as the reader changes size without shrinking toward an
  /// illegible caption. The same floor as source text protects the smallest
  /// reading setting.
  double get footnote {
    final reduced = base - 2;
    return reduced < minimumCodeSize ? minimumCodeSize : reduced;
  }

  /// Table text, slightly smaller so a table stays a table.
  double get tableText => base * 0.9;

  ReadingScale copyWith({
    double? base,
    double? leading,
    double? measure,
    ParagraphMarking? marking,
  }) => ReadingScale(
    base: base ?? this.base,
    leading: leading ?? this.leading,
    measure: measure ?? this.measure,
    marking: marking ?? this.marking,
  );

  @override
  bool operator ==(Object other) =>
      other is ReadingScale &&
      other.base == base &&
      other.leading == leading &&
      other.measure == measure &&
      other.marking == marking;

  @override
  int get hashCode => Object.hash(base, leading, measure, marking);
}

/// The two ways a page tells one paragraph from the next.
///
/// They are alternatives, not companions. A space and an indent are the same
/// signal said twice; using both is the mark of a page that does not trust
/// its reader. Screens have settled on the space; books have always used the
/// indent, which wastes no vertical room and keeps a column solid.
enum ParagraphMarking {
  /// A gap between paragraphs, no indent. The screen convention.
  spaced,

  /// An indented first line, no gap. The book convention — and the first
  /// paragraph after a heading is never indented, because an indent signals
  /// a break and nothing has been broken from yet.
  indented,
}
