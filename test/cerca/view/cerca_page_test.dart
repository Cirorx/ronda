import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ronda/cerca/cerca.dart';

import '../../helpers/helpers.dart';

void main() {
  group(CercaPage, () {
    group('renders', () {
      testWidgets('its title in the app bar', (tester) async {
        await tester.pumpApp(const CercaPage());

        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.text('Cerca'),
          ),
          findsOneWidget,
        );
      });

      testWidgets('its placeholder line', (tester) async {
        await tester.pumpApp(const CercaPage());

        expect(find.text('Todavía no hay grupos acá'), findsOneWidget);
      });
    });
  });
}
