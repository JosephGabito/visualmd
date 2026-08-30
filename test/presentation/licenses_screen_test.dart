import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/api/screens/licenses_screen.dart';
import 'package:visualmd/api/theme/library_theme.dart';
import 'package:visualmd/presentation/theme/theme_choice.dart';
import 'package:visualmd/presentation/theme/theme_registry.dart';

void main() {
  testWidgets('licenses use a readable page with an explicit close action', (
    tester,
  ) async {
    LicenseRegistry.addLicense(() async* {
      yield const _TestLicenseEntry();
    });
    final registry = ThemeRegistry();
    final paper = registry.resolve(const FixedTheme('paper'), Brightness.light);

    await tester.pumpWidget(
      MaterialApp(
        theme: libraryTheme(paper),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const LicensesScreen(
                  topBar: (height: 52, leadingInset: 76),
                  windowDragRegion: _identity,
                ),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Open-Source Licenses'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsNothing);
    expect(find.text('visual-md-test-package'), findsWidgets);
    expect(
      find.text('A short license written only for this widget test.'),
      findsOneWidget,
    );
    expect(find.text('A centred copyright notice.'), findsOneWidget);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Open'), findsOneWidget);
  });
}

Widget _identity(Widget child) => child;

final class _TestLicenseEntry extends LicenseEntry {
  const _TestLicenseEntry();

  @override
  Iterable<String> get packages => const ['visual-md-test-package'];

  @override
  Iterable<LicenseParagraph> get paragraphs => const [
    LicenseParagraph(
      'A centred copyright notice.',
      LicenseParagraph.centeredIndent,
    ),
    LicenseParagraph('A short license written only for this widget test.', 0),
  ];
}
