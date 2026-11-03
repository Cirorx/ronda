import 'package:flutter_test/flutter_test.dart';
import 'package:ronda/cerca/cerca.dart';
import 'package:ronda_ui/ronda_ui.dart';

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

      testWidgets("an almacén's door with a notice over the words", (
        tester,
      ) async {
        await tester.pumpApp(const CercaPage());

        final sketch = findSketch(RondaScene.almacenNotice);
        expect(sketch, findsOneWidget);
        expect(
          tester.getBottomLeft(sketch).dy,
          lessThan(tester.getTopLeft(find.textContaining('Pronto')).dy),
        );
      });

      testWidgets('inside the page margins', (tester) async {
        await tester.pumpApp(const CercaPage());

        final text = tester.getRect(find.textContaining('Pronto vas a ver'));
        expect(text.left, greaterThan(0));
        expect(text.right, lessThan(phoneSize.width));
      });

      testWidgets('at 200% text without overflowing', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        await tester.pumpApp(const CercaPage());

        expect(tester.takeException(), isNull);
      });
    });
  });
}
