import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ronda/my_ronda/my_ronda.dart';

import '../../helpers/helpers.dart';

void main() {
  group(MyRondaPage, () {
    group('renders', () {
      testWidgets('its title in the app bar', (tester) async {
        await tester.pumpApp(const MyRondaPage());

        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.text('Mi ronda'),
          ),
          findsOneWidget,
        );
      });

      testWidgets('its placeholder line', (tester) async {
        await tester.pumpApp(const MyRondaPage());

        expect(find.text('Estamos armando tu grupo'), findsOneWidget);
      });

      testWidgets('its content under the identifier Maestro waits for', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await tester.pumpApp(const MyRondaPage());

        expect(
          tester.getSemantics(
            find.bySemanticsIdentifier(MyRondaPage.identifier),
          ),
          isSemantics(
            identifier: MyRondaPage.identifier,
            label: 'Estamos armando tu grupo',
          ),
        );
        handle.dispose();
      });
    });
  });
}
