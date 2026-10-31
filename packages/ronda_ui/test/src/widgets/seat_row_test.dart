import 'package:flutter_test/flutter_test.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';

void main() {
  group(SeatRow, () {
    late int taps;

    setUp(() => taps = 0);

    Widget buildSubject({String? note, SeatCount? seats}) {
      return SingleChildScrollView(
        child: SeatRow(
          identifier: 'cerca.mate',
          title: 'Mate en la rambla',
          availability: 'Quedan 2 lugares',
          detail: 'Solymar · jueves de tarde',
          note: note,
          seats: seats,
          onTap: () => taps++,
        ),
      );
    }

    SeatCount seatsOf({int filled = 4, int total = 6}) => SeatCount(
      filled: filled,
      total: total,
      semanticsLabel: '$filled de $total anotados',
    );

    group('renders', () {
      testWidgets('the title, availability and detail', (tester) async {
        await tester.pumpApp(buildSubject());

        expect(find.text('Mate en la rambla'), findsOneWidget);
        expect(find.text('Quedan 2 lugares'), findsOneWidget);
        expect(find.text('Solymar · jueves de tarde'), findsOneWidget);
      });

      testWidgets('the note when given', (tester) async {
        await tester.pumpApp(buildSubject(note: 'Lo organiza Rosa.'));

        expect(find.text('Lo organiza Rosa.'), findsOneWidget);
      });

      testWidgets('the card as one button read as one item', (tester) async {
        await tester.pumpApp(buildSubject(seats: seatsOf()));

        expect(
          tester.getSemantics(find.bySemanticsIdentifier('cerca.mate')),
          isSemantics(
            label:
                'Mate en la rambla\nQuedan 2 lugares\n'
                'Solymar · jueves de tarde\n4 de 6 anotados',
            isButton: true,
            hasTapAction: true,
          ),
        );
      });

      testWidgets('a 48 dp tap target', (tester) async {
        await tester.pumpApp(buildSubject());

        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      });

      for (final MapEntry(key: name, value: theme) in themes.entries) {
        for (final scale in textScales) {
          testWidgets('without overflow in $name at ${scale}x text', (
            tester,
          ) async {
            await tester.pumpApp(
              buildSubject(
                note: 'Hay gente de 20 y pico a 70 y pico.',
                seats: seatsOf(),
              ),
              theme: theme(),
              textScale: scale,
            );

            expect(tester.takeException(), isNull);
          });
        }
      }
    });

    group('calls onTap', () {
      testWidgets('when the card is tapped', (tester) async {
        await tester.pumpApp(buildSubject());

        await tester.tap(find.bySemanticsIdentifier('cerca.mate'));

        expect(taps, 1);
      });
    });

    testWidgets('grows a newly taken seat from part of its size, not zero', (
      tester,
    ) async {
      final filled = ValueNotifier(0);
      addTearDown(filled.dispose);
      await tester.pumpApp(
        ValueListenableBuilder(
          valueListenable: filled,
          builder: (context, value, _) =>
              buildSubject(seats: seatsOf(filled: value, total: 1)),
        ),
      );
      Finder inFill(Type type) => find.descendant(
        of: find.byType(SpringBuilder),
        matching: find.byType(type),
      );

      filled.value = 1;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      // The x scale; the matrix's z stays 1.
      final scale = tester.widget<Transform>(inFill(Transform)).transform[0];
      expect(scale, greaterThanOrEqualTo(SeatRow.fillStartScale));
      expect(scale, lessThan(1));
      expect(tester.widget<Opacity>(inFill(Opacity)).opacity, lessThan(1));

      await tester.pumpAndSettle();
      expect(tester.widget<Opacity>(inFill(Opacity)).opacity, 1);
    });

    testWidgets(
      'tints the card under a mouse over ${AppMotion.hover.inMilliseconds} ms',
      (tester) async {
        await tester.pumpApp(buildSubject());

        expect(
          tester.widget<InkWell>(find.byType(InkWell)).hoverDuration,
          AppMotion.hover,
        );
      },
    );
  });
}
