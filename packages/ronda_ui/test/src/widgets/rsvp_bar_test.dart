import 'package:flutter_test/flutter_test.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';

void main() {
  group(RsvpBar, () {
    late List<String> answers;

    setUp(() => answers = []);

    Widget buildSubject({String? message = 'Te toca llevar el pan.'}) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.unit),
        child: RsvpBar(
          identifier: 'rsvp',
          question: '¿Venís?',
          message: message,
          yesLabel: 'Voy',
          noLabel: 'Esta no',
          onYes: () => answers.add('voy'),
          onNo: () => answers.add('esta no'),
        ),
      );
    }

    group('renders', () {
      testWidgets('the question as a header, the message and both buttons', (
        tester,
      ) async {
        await tester.pumpApp(buildSubject());

        expect(
          tester.getSemantics(find.text('¿Venís?')),
          isSemantics(isHeader: true),
        );
        expect(find.text('Te toca llevar el pan.'), findsOneWidget);
        expect(find.byType(FilledButton), findsOneWidget);
        expect(find.byType(OutlinedButton), findsOneWidget);
      });

      testWidgets('no message when none is given', (tester) async {
        await tester.pumpApp(buildSubject(message: null));

        expect(find.text('Te toca llevar el pan.'), findsNothing);
      });

      testWidgets('the buttons side by side at normal text', (tester) async {
        await tester.pumpApp(buildSubject());

        expect(
          tester.getTopLeft(find.text('Voy')).dy,
          tester.getTopLeft(find.text('Esta no')).dy,
        );
      });

      testWidgets('the buttons stacked with large text', (tester) async {
        await tester.pumpApp(
          buildSubject(),
          textScale: AppTheme.largeTextScale,
        );

        expect(
          tester.getTopLeft(find.byType(FilledButton)).dy,
          lessThan(tester.getTopLeft(find.byType(OutlinedButton)).dy),
        );
      });

      testWidgets('buttons with identifiers and 48 dp targets', (tester) async {
        await tester.pumpApp(buildSubject());

        expect(
          tester.getSemantics(find.bySemanticsIdentifier('rsvp.yes')),
          isSemantics(label: 'Voy', isButton: true, hasTapAction: true),
        );
        expect(
          tester.getSemantics(find.bySemanticsIdentifier('rsvp.no')),
          isSemantics(label: 'Esta no', isButton: true, hasTapAction: true),
        );
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      });

      for (final MapEntry(key: name, value: theme) in themes.entries) {
        for (final scale in textScales) {
          testWidgets('without overflow in $name at ${scale}x text', (
            tester,
          ) async {
            await tester.pumpApp(
              buildSubject(),
              theme: theme(),
              textScale: scale,
            );

            expect(tester.takeException(), isNull);
          });
        }
      }
    });

    group('calls', () {
      testWidgets('onYes when "Voy" is tapped', (tester) async {
        await tester.pumpApp(buildSubject());

        await tester.tap(find.bySemanticsIdentifier('rsvp.yes'));

        expect(answers, ['voy']);
      });

      testWidgets('onNo when "Esta no" is tapped', (tester) async {
        await tester.pumpApp(buildSubject());

        await tester.tap(find.bySemanticsIdentifier('rsvp.no'));

        expect(answers, ['esta no']);
      });
    });

    group('while an answer is on its way', () {
      Widget pending(RsvpBarAnswer answer) => RsvpBar(
        identifier: 'rsvp',
        question: '¿Venís?',
        message: 'Te toca llevar el pan.',
        yesLabel: 'Voy',
        noLabel: 'Esta no',
        onYes: () => answers.add('voy'),
        onNo: () => answers.add('esta no'),
        pending: answer,
        savingLabel: 'Guardando tu respuesta…',
      );

      for (final answer in RsvpBarAnswer.values) {
        testWidgets('rings ${answer.name}, turns the other off and says so', (
          tester,
        ) async {
          final semantics = tester.ensureSemantics();
          final haptics = recordHaptics(tester);
          await tester.pumpApp(pending(answer));

          final other = RsvpBarAnswer.values.firstWhere((a) => a != answer);
          expect(progressIn('rsvp.${answer.name}'), findsOneWidget);
          expect(progressIn('rsvp.${other.name}'), findsNothing);
          expect(find.text('¿Venís?'), findsOneWidget);
          expect(find.text('Te toca llevar el pan.'), findsOneWidget);
          expect(
            tester.getSemantics(find.text('Guardando tu respuesta…')),
            isSemantics(isLiveRegion: true),
          );
          expect(
            tester.getSemantics(
              find.bySemanticsIdentifier('rsvp.${other.name}'),
            ),
            isSemantics(
              isButton: true,
              hasEnabledState: true,
              isEnabled: false,
            ),
          );

          await tester.tap(find.text('Voy'), warnIfMissed: false);
          await tester.tap(find.text('Esta no'), warnIfMissed: false);
          // Even reached past its IgnorePointer, the pressed one does nothing.
          tester
              .widget<ButtonStyleButton>(
                find.descendant(
                  of: byIdentifier('rsvp.${answer.name}'),
                  matching: find.bySubtype<ButtonStyleButton>(),
                ),
              )
              .onPressed!();
          expect(answers, isEmpty);
          expect(haptics, isEmpty);
          semantics.dispose();
        });
      }

      testWidgets('stacks the buttons with large text', (tester) async {
        await tester.pumpApp(
          pending(RsvpBarAnswer.yes),
          textScale: AppTheme.largeTextScale,
        );

        expect(
          find.ancestor(of: find.text('Voy'), matching: find.byType(Expanded)),
          findsNothing,
        );
        expect(progressIn('rsvp.yes'), findsOneWidget);
      });

      testWidgets('says nothing under the buttons without a saving line', (
        tester,
      ) async {
        await tester.pumpApp(
          RsvpBar(
            identifier: 'rsvp',
            question: '¿Venís?',
            yesLabel: 'Voy',
            noLabel: 'Esta no',
            onYes: () {},
            onNo: () {},
            pending: RsvpBarAnswer.no,
          ),
        );

        expect(find.byType(StatusLine), findsNothing);
        expect(progressIn('rsvp.no'), findsOneWidget);
      });
    });

    group('commits', () {
      for (final (identifier, answer) in [
        ('rsvp.yes', 'voy'),
        ('rsvp.no', 'esta no'),
      ]) {
        testWidgets('$answer with a light haptic before the callback', (
          tester,
        ) async {
          final haptics = recordHaptics(tester);
          final order = <String>[];
          await tester.pumpApp(
            RsvpBar(
              identifier: 'rsvp',
              question: '¿Venís?',
              yesLabel: 'Voy',
              noLabel: 'Esta no',
              onYes: () => order.add('voy after ${haptics.length}'),
              onNo: () => order.add('esta no after ${haptics.length}'),
            ),
          );

          await tester.tap(find.bySemanticsIdentifier(identifier));

          expect(haptics, ['HapticFeedbackType.lightImpact']);
          expect(order, ['$answer after 1']);
        });
      }
    });
  });
}
