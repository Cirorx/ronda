import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ronda/onboarding/onboarding.dart';
import 'package:ronda/onboarding/view/steps/steps.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// The voice recorder, what a voice note left out, or the open onboarding
/// step, moving from one to the next as pushed screens do
/// ([StepSwitcher]). The system back button leaves the recorder for the
/// questions, goes from what a note left out back to the recorder, and
/// steps back through the
/// questions instead of leaving; on the first question it calls [onLeave],
/// or leaves when there is none. The first question's back button calls
/// [onLeave] too ([OnboardingLeaveScope]).
class const OnboardingView({
  /// Back from the first question: to the welcome doors signed out, to the
  /// recorder signed in.
  final VoidCallback? onLeave,

  /// "Ya tengo cuenta" on the first question, signed out.
  final VoidCallback? onSignIn,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final pages = OnboardingPages.of(context);
    final open = context.select<OnboardingCubit, OnboardingScreen>(
      (cubit) => OnboardingScreen.of(cubit.state),
    );
    // On a page of several questions the screen is the page's: moving
    // between its questions doesn't move.
    final page = OnboardingPages.pageOf(pages, open.step);
    final screen = page == null
        ? open
        : OnboardingScreen(step: page.first, editing: open.editing);
    final recording = screen.step == null;
    final onFirstQuestion =
        screen.step == OnboardingStep.values.first && !screen.editing;
    return PopScope(
      canPop: onFirstQuestion && onLeave == null,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (onFirstQuestion) {
          onLeave?.call();
          return;
        }
        final cubit = context.read<OnboardingCubit>();
        if (screen.gaps) {
          cubit.recordAgain();
        } else if (recording) {
          cubit.voiceCancelled();
        } else if (page != null && page.length > 1) {
          cubit.backTo(pages[pages.indexOf(page) - 1].first);
        } else {
          cubit.back();
        }
      },
      child: OnboardingLeaveScope(
        onLeave: onLeave,
        onSignIn: onSignIn,
        child: StepSwitcher<OnboardingScreen>(
          step: screen,
          forward: (from, to) => to.isForwardFrom(from),
          child: switch (screen.step) {
            _ when screen.gaps => const VoiceGapsStep(),
            _ when page != null && page.length > 1 => OnboardingQuestionPage(
              page: page,
              pages: pages,
              child: OnboardingSectionScope(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: context.appSpacing.xlg,
                  children: [for (final step in page) question(step)],
                ),
              ),
            ),
            null => const VoiceNoteStep(),
            final step => question(step),
          },
        ),
      ),
    );
  }

  /// The screen that asks [step].
  static Widget question(OnboardingStep step) => switch (step) {
    OnboardingStep.pretexts => const PretextsStep(),
    OnboardingStep.brings => const BringsStep(),
    OnboardingStep.slots => const SlotsStep(),
    OnboardingStep.barrio => const BarrioStep(),
    OnboardingStep.ageBand => const AgeBandStep(),
    OnboardingStep.needs => const NeedsStep(),
    OnboardingStep.firstName => const FirstNameStep(),
    OnboardingStep.review => const ReviewStep(),
  };
}
