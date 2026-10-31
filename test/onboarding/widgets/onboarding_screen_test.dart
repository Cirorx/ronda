import 'package:flutter_test/flutter_test.dart';
import 'package:ronda/onboarding/onboarding.dart';

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
}
