import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ronda/onboarding/onboarding.dart';
import 'package:ronda/onboarding/view/steps/steps.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// The voice recorder, or the open onboarding step. The system back button
/// leaves the recorder for the questions, and steps back through the
/// questions instead of leaving.
class const OnboardingView({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final step = context.select<OnboardingCubit, OnboardingStep>(
      (cubit) => cubit.state.step,
    );
    final editingFromReview = context.select<OnboardingCubit, bool>(
      (cubit) => cubit.state.editingFromReview,
    );
    final recording = context.select<OnboardingCubit, bool>(
      (cubit) => cubit.state.recording,
    );
    return PopScope(
      canPop:
          step == OnboardingStep.values.first &&
          !editingFromReview &&
          !recording,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final cubit = context.read<OnboardingCubit>();
        recording ? cubit.voiceCancelled() : cubit.back();
      },
      child: switch (step) {
        _ when recording => const VoiceNoteStep(),
        OnboardingStep.pretexts => const PretextsStep(),
        OnboardingStep.brings => const BringsStep(),
        OnboardingStep.slots => const SlotsStep(),
        OnboardingStep.barrio => const BarrioStep(),
        OnboardingStep.ageBand => const AgeBandStep(),
        OnboardingStep.needs => const NeedsStep(),
        OnboardingStep.firstName => const FirstNameStep(),
        OnboardingStep.review => const ReviewStep(),
      },
    );
  }
}
