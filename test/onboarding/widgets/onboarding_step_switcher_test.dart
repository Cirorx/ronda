import 'package:flutter_test/flutter_test.dart';
import 'package:ronda/onboarding/onboarding.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';

const _recorder = OnboardingScreen();
const _brings = OnboardingScreen(step: OnboardingStep.brings);
const _slots = OnboardingScreen(step: OnboardingStep.slots);
const _review = OnboardingScreen(step: OnboardingStep.review);
const _editingSlots = OnboardingScreen(
  step: OnboardingStep.slots,
  editing: true,
);

void main() {
  group(OnboardingScreen, () {
    group('of', () {
      test('is the recorder while recording, whatever the step', () {
        expect(
          OnboardingScreen.of(
            const OnboardingState(step: OnboardingStep.review, recording: true),
          ),
          equals(_recorder),
        );
      });

      test('is the open step, and whether it came from "Cambiar"', () {
        expect(
          OnboardingScreen.of(
            const OnboardingState(
              step: OnboardingStep.slots,
              editingFromReview: true,
            ),
          ),
          equals(_editingSlots),
        );
      });
    });

    group('questionNumber', () {
      test('counts the questions from 1', () {
        expect(_slots.questionNumber, equals(3));
      });

      test('is null on the read-back and the recorder', () {
        expect(_review.questionNumber, isNull);
        expect(_recorder.questionNumber, isNull);
      });
    });

    group('isForwardFrom', () {
      for (final (from, to, forward, why) in [
        (_brings, _slots, true, 'on to a later question'),
        (_slots, _brings, false, 'back to an earlier question'),
        (_review, _editingSlots, true, 'into a "Cambiar"'),
        (_editingSlots, _review, false, 'out of a "Cambiar"'),
        (_review, _recorder, true, 'into the recorder'),
        (_recorder, _review, true, 'out of the recorder'),
        (_recorder, _brings, true, 'from the recorder to the questions'),
      ]) {
        test('is $forward $why', () {
          expect(to.isForwardFrom(from), equals(forward));
        });
      }
    });
  });

  group(OnboardingStepSwitcher, () {
    Widget screen(String name) => Scaffold(
      body: Center(
        child: TextButton(onPressed: () {}, child: Text(name)),
      ),
    );

    Widget buildSubject(OnboardingScreen open) => OnboardingStepSwitcher(
      screen: open,
      child: Builder(
        builder: (context) => Column(
          children: [
            Text(
              'from '
              '${OnboardingStepSwitcher.previousQuestionOf(context)}',
            ),
            Expanded(child: screen('${open.step?.name}')),
          ],
        ),
      ),
    );

    testWidgets('shows the open screen', (tester) async {
      await tester.pumpApp(buildSubject(_brings));

      expect(find.text('brings'), findsOneWidget);
      expect(find.text('from null'), findsOneWidget);
    });

    testWidgets('tells the new screen which question came before', (
      tester,
    ) async {
      await tester.pumpApp(buildSubject(_brings));

      await tester.pumpApp(buildSubject(_slots));
      await tester.pumpAndSettle();

      expect(find.text('slots'), findsOneWidget);
      expect(find.text('brings'), findsNothing);
      expect(find.text('from 2'), findsOneWidget);
    });

    testWidgets('lets only the new screen be read and touched', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpApp(buildSubject(_brings));

      await tester.pumpApp(buildSubject(_slots));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('brings'), findsOneWidget);
      expect(find.semantics.byLabel('slots'), findsOne);
      expect(find.semantics.byLabel('brings'), findsNothing);
      final leaving = tester.widget<IgnorePointer>(
        find
            .ancestor(
              of: find.text('brings'),
              matching: find.byType(IgnorePointer),
            )
            .first,
      );
      expect(leaving.ignoring, isTrue);
      semantics.dispose();
    });

    testWidgets('slides in from the left in a right-to-left language', (
      tester,
    ) async {
      Widget rtl(OnboardingScreen open) => Directionality(
        textDirection: TextDirection.rtl,
        child: buildSubject(open),
      );
      await tester.pumpApp(rtl(_brings));

      await tester.pumpApp(rtl(_slots));
      await tester.pump(const Duration(milliseconds: 50));

      final incoming = tester.widget<SlideTransition>(
        find
            .ancestor(
              of: find.text('slots'),
              matching: find.byType(SlideTransition),
            )
            .first,
      );
      expect(incoming.position.value.dx, inExclusiveRange(-1, 0));
    });

    testWidgets('changes at once while the page itself is coming in', (
      tester,
    ) async {
      final open = ValueNotifier(_brings);
      addTearDown(open.dispose);
      await tester.pumpApp(const SizedBox());
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));

      navigator
          .push(
            MaterialPageRoute<void>(
              builder: (_) => ValueListenableBuilder(
                valueListenable: open,
                builder: (_, screen, _) => buildSubject(screen),
              ),
            ),
          )
          .ignore();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      open.value = _review;
      await tester.pump();

      expect(find.text('brings'), findsNothing);
      expect(find.text('review'), findsOneWidget);
    });
  });
}
