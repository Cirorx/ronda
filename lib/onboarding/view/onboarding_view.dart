import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ronda/onboarding/onboarding.dart';
import 'package:ronda/onboarding/view/steps/steps.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// The voice recorder, or the open onboarding step, moving from one to the
/// next as pushed screens do ([StepSwitcher]). The system back
/// button leaves the recorder for the questions, and steps back through the
/// questions instead of leaving; on the first question it calls [onLeave],
/// or leaves when there is none.
class const OnboardingView({
  /// Back from the first question (to the welcome doors, signed out).
  final VoidCallback? onLeave,
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
        if (recording) {
          cubit.voiceCancelled();
        } else if (page != null && page.length > 1) {
          cubit.backTo(pages[pages.indexOf(page) - 1].first);
        } else {
          cubit.back();
        }
      },
      child: StepSwitcher<OnboardingScreen>(
        step: screen,
        forward: (from, to) => to.isForwardFrom(from),
        child: switch (screen.step) {
          _ when page != null && page.length > 1 => OnboardingQuestionPage(
            page: page,
            pages: pages,
            child: OnboardingSectionScope(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: context.appSpacing.xlg,
                children: [for (final step in page) _question(step)],
              ),
            ),
          ),
          null => const VoiceNoteStep(),
          final step => _question(step),
        },
      ),
    );
  }

  static Widget _question(OnboardingStep step) => switch (step) {
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
