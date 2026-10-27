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
  });
}
