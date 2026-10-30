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

      testWidgets('that the list is coming, and where your group shows', (
        tester,
      ) async {
        await tester.pumpApp(const CercaPage());

        expect(
          find.text(
            'Pronto vas a ver acá los grupos cerca tuyo que tienen lugar. '
            'Mientras tanto, si tenés grupo, lo ves en Mi ronda.',
          ),
          findsOneWidget,
        );
      });
    });
  });
}
