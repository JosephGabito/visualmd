import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/api/theme/library_theme.dart';
import 'package:visualmd/api/widgets/chrome_list_row.dart';
import 'package:visualmd/api/widgets/outline_panel.dart';
import 'package:visualmd/domain/reading/heading.dart';
import 'package:visualmd/domain/reading/table_of_contents.dart';
import 'package:visualmd/presentation/theme/built_in_themes.dart';

void main() {
  testWidgets('an enormous outline mounts only its visible rows', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final headings = [
      for (var index = 0; index < 10000; index++)
        Heading(
          level: index == 0 ? 1 : 2,
          text: 'Section $index',
          anchor: 'section-$index',
        ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: libraryTheme(BuiltInThemes.paper),
        home: Scaffold(
          body: OutlinePanel(
            tableOfContents: TableOfContents(headings),
            activeAnchor: headings.first.anchor,
            onSelect: (_) {},
          ),
        ),
      ),
    );

    expect(find.byType(ChromeListRow), findsWidgets);
    expect(find.byType(ChromeListRow).evaluate().length, lessThan(30));
    expect(find.text('Section 9999'), findsNothing);
  });
}
