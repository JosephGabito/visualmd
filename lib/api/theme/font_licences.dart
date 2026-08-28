import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The bundled typefaces and the licence file that must travel with each.
/// All three are SIL Open Font License 1.1 with no reserved font names.
const bundledFontLicences = {
  'Literata': 'assets/fonts/LICENSE-Literata.txt',
  'Inter': 'assets/fonts/LICENSE-Inter.txt',
  'Geist Mono': 'assets/fonts/LICENSE-GeistMono.txt',
  'Alegreya': 'assets/fonts/LICENSE-Alegreya.txt',
};

/// Adds the font licences to the registry behind `showLicensePage`, which is
/// how the OFL notice reaches anyone reading with them.
void registerFontLicences() {
  LicenseRegistry.addLicense(() async* {
    for (final entry in bundledFontLicences.entries) {
      yield LicenseEntryWithLineBreaks([
        entry.key,
      ], await rootBundle.loadString(entry.value));
    }
  });
}

/// Adds notices for source bundled inside generated third-party assets.
///
/// Flutter registers package licences automatically, but Shiki's generated
/// worker also contains TextMate grammars and themes whose notices belong to
/// their upstream projects rather than to the Dart package itself.
void registerGeneratedAssetLicences() {
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(
      const ['Shiki bundled grammars, themes, and supporting libraries'],
      await rootBundle.loadString(
        'assets/licenses/shiki_flutter-1.1.0-THIRD_PARTY_NOTICES.md',
      ),
    );
  });
}

/// The optical-size axis of each bundled face, where it has one.
///
/// A face with an `opsz` axis is really several designs: at reading sizes the
/// letters are wider and the strokes sturdier, at display sizes they tighten
/// and the hairlines thin. Handing the axis the size we are actually drawing
/// at is the difference between a font that has been scaled and one that has
/// been designed.
const bundledOpticalSizes = <String, (double, double)>{
  'Literata': (7, 72),
  'Inter': (14, 32),
};
