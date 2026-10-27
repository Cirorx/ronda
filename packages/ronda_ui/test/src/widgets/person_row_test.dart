import 'package:flutter_test/flutter_test.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';

void main() {
  group(PersonRow, () {
    Widget buildSubject({bool isYou = false, bool showDivider = true}) {
      return Column(
        children: [
          PersonRow(
            initial: 'M',
            name: isYou ? 'Vos' : 'Mirta',
            detail: 'Llega primero · lleva el termo',
            isYou: isYou,
            showDivider: showDivider,
          ),
        ],
      );
    }

    group('renders', () {
      testWidgets('the initial, the name and the detail', (tester) async {
        await tester.pumpApp(buildSubject());

        expect(find.text('M'), findsOneWidget);
        expect(find.text('Mirta'), findsOneWidget);
        expect(find.text('Llega primero · lleva el termo'), findsOneWidget);
      });

      testWidgets('the name and detail as one item, without the initial', (
        tester,
      ) async {
        await tester.pumpApp(buildSubject());

        expect(
          tester.getSemantics(find.text('Mirta')),
          isSemantics(label: 'Mirta\nLlega primero · lleva el termo'),
        );
      });

      testWidgets('the person using the app', (tester) async {
        await tester.pumpApp(buildSubject(isYou: true));

        expect(find.text('Vos'), findsOneWidget);
        expect(find.text('M'), findsOneWidget);
      });

      testWidgets('at least ${PersonRow.minRowHeight} dp tall', (tester) async {
        await tester.pumpApp(buildSubject(showDivider: false));

        expect(
          tester.getSize(find.byType(PersonRow)).height,
          greaterThanOrEqualTo(PersonRow.minRowHeight),
        );
      });

      testWidgets('only the words with large text', (tester) async {
        await tester.pumpApp(
          buildSubject(),
          textScale: AppTheme.largeTextScale,
        );

        expect(find.text('M'), findsNothing);
        expect(find.text('Mirta'), findsOneWidget);
      });

      for (final MapEntry(key: name, value: theme) in themes.entries) {
        for (final scale in textScales) {
          for (final isYou in [false, true]) {
            testWidgets('without overflow in $name at ${scale}x '
                '(${isYou ? 'you' : 'neighbour'})', (tester) async {
              await tester.pumpApp(
                buildSubject(isYou: isYou),
                theme: theme(),
                textScale: scale,
              );

              expect(tester.takeException(), isNull);
            });
          }
        }
      }
    });
  });
}
