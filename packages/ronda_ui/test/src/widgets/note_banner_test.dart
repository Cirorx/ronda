import 'package:flutter_test/flutter_test.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';

void main() {
  group(NoteBanner, () {
    group('renders', () {
      for (final variant in NoteBannerVariant.values) {
        testWidgets('the message for ${variant.name}', (tester) async {
          await tester.pumpApp(
            NoteBanner(message: 'Sin señal.', variant: variant),
          );

          expect(find.text('Sin señal.'), findsOneWidget);
        });
      }

      testWidgets('the title above the message when given', (tester) async {
        await tester.pumpApp(
          const NoteBanner(
            title: 'Jueves 16:00 · lluvia 80%',
            message: 'Ráfagas de 50 km/h.',
            variant: NoteBannerVariant.warning,
          ),
        );

        expect(find.text('Jueves 16:00 · lluvia 80%'), findsOneWidget);
        expect(
          tester.getTopLeft(find.text('Jueves 16:00 · lluvia 80%')).dy,
          lessThan(tester.getTopLeft(find.text('Ráfagas de 50 km/h.')).dy),
        );
      });

      testWidgets('the icon when given', (tester) async {
        await tester.pumpApp(
          const NoteBanner(
            message: 'Queda guardado solo en este teléfono',
            variant: NoteBannerVariant.keptOnPhone,
            icon: Icons.lock_outline,
          ),
        );

        expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      });

      testWidgets('only as tall as its text', (tester) async {
        await tester.pumpApp(const NoteBanner(message: 'Hola'));

        expect(
          tester.getSize(find.byType(NoteBanner)).height,
          lessThan(phoneSize.height / 4),
        );
      });

      testWidgets('no icon by default', (tester) async {
        await tester.pumpApp(const NoteBanner(message: 'Hola'));

        expect(find.byType(Icon), findsNothing);
      });

      testWidgets('as a live region that reads its text', (tester) async {
        await tester.pumpApp(
          const NoteBanner(
            message: 'Sin señal. Te mostramos lo último que vimos.',
            variant: NoteBannerVariant.offline,
          ),
        );

        expect(
          tester.getSemantics(find.byType(NoteBanner)),
          isSemantics(
            isLiveRegion: true,
            label: 'Sin señal. Te mostramos lo último que vimos.',
          ),
        );
      });

      for (final MapEntry(key: name, value: theme) in themes.entries) {
        for (final scale in textScales) {
          for (final variant in NoteBannerVariant.values) {
            testWidgets(
              'without overflow for ${variant.name} in $name at ${scale}x',
              (tester) async {
                await tester.pumpApp(
                  NoteBanner(
                    title: 'Jueves 16:00 · lluvia 80%',
                    message: 'Si te querés ir antes, decí «me tengo que ir».',
                    variant: variant,
                    icon: Icons.info_outline,
                  ),
                  theme: theme(),
                  textScale: scale,
                );

                expect(tester.takeException(), isNull);
              },
            );
          }
        }
      }
    });
  });
}
