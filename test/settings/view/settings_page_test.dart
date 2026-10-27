import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ronda/settings/settings.dart';

import '../../helpers/helpers.dart';

void main() {
  group(SettingsPage, () {
    group('renders', () {
      testWidgets('its title in the app bar', (tester) async {
        await tester.pumpApp(const SettingsPage());

        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.text('Ajustes'),
          ),
          findsOneWidget,
        );
      });

      testWidgets('its placeholder line', (tester) async {
        await tester.pumpApp(const SettingsPage());

        expect(
          find.text(
            'Acá vas a poder tomarte unas semanas, cambiarte de grupo o '
            'dejar Ronda.',
          ),
          findsOneWidget,
        );
      });
    });
  });
}
