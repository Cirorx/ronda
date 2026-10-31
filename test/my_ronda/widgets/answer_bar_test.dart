import 'package:flutter_test/flutter_test.dart';
import 'package:ronda/my_ronda/widgets/answer_bar.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';

void main() {
  group(AnswerBar, () {
    late List<String> calls;

    setUp(() => calls = []);

    Future<void> pump(
      WidgetTester tester, {
      AnswerSide? pending,
      double textScale = 1,
    }) => tester.pumpApp(
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            body: AnswerBar(
              identifier: 'rsvp',
              question: '¿Venís?',
              message: 'Te toca llevar el pan.',
              yesLabel: 'Voy',
              noLabel: 'Esta no',
              onYes: () => calls.add('yes'),
              onNo: () => calls.add('no'),
              savingLabel: 'Guardando tu respuesta…',
              pending: pending,
            ),
          ),
        ),
      ),
    );

    testWidgets('is the shared $RsvpBar while nothing is on its way', (
      tester,
    ) async {
      final haptics = recordHaptics(tester);
      await pump(tester);

      expect(find.byType(RsvpBar), findsOneWidget);
      await tester.tap(find.text('Voy'));
      expect(calls, ['yes']);
      expect(haptics, [commitHaptic]);
    });

    for (final side in AnswerSide.values) {
      testWidgets('rings ${side.name} and turns the other off', (tester) async {
        final haptics = recordHaptics(tester);
        await pump(tester, pending: side);

        final other = AnswerSide.values.firstWhere((each) => each != side);
        expect(progressIn('rsvp.${side.name}'), findsOneWidget);
        expect(progressIn('rsvp.${other.name}'), findsNothing);
        expect(find.text('¿Venís?'), findsOneWidget);
        expect(find.text('Te toca llevar el pan.'), findsOneWidget);
        expect(find.text('Guardando tu respuesta…'), findsOneWidget);

        await tester.tap(find.text('Voy'), warnIfMissed: false);
        await tester.tap(find.text('Esta no'), warnIfMissed: false);
        expect(calls, isEmpty);
        expect(haptics, isEmpty);
      });
    }

    testWidgets('stacks the buttons at large text while one is on its way', (
      tester,
    ) async {
      await pump(tester, pending: AnswerSide.yes, textScale: 2);

      expect(
        find.ancestor(of: find.text('Voy'), matching: find.byType(Expanded)),
        findsNothing,
      );
      expect(progressIn('rsvp.yes'), findsOneWidget);
    });
  });
}
