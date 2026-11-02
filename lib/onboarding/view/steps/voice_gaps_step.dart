import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/onboarding/onboarding.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// "Nos falta poco": only the questions a voice note left unanswered, each
/// with its own picker, together on one screen; "Seguir" opens the
/// read-back once they are answered. A note that answered everything never
/// shows it.
class const VoiceGapsStep({super.key}) extends StatelessWidget {
  /// Maestro's handle on "Seguir".
  static const nextIdentifier = 'onboarding.gaps.next';

  /// Maestro's handle on "Grabar de nuevo".
  static const recordAgainIdentifier = 'onboarding.gaps.recordAgain';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final gaps = context.select<OnboardingCubit, List<OnboardingStep>>(
      (cubit) => cubit.state.gaps,
    );
    final filled = context.select<OnboardingCubit, bool>(
      (cubit) => cubit.state.gaps.every(cubit.state.isAnswered),
    );
    final cubit = context.read<OnboardingCubit>();
    return OnboardingStepLayout(
      barTitle: l10n.voiceBarTitle,
      title: l10n.voiceGapsTitle,
      body: l10n.voiceGapsBody(gaps.length),
      onBack: cubit.recordAgain,
      primaryAction: MergeSemantics(
        child: Semantics(
          identifier: nextIdentifier,
          child: FilledButton(
            onPressed: filled ? cubit.gapsFilled : null,
            child: Text(l10n.onboardingNext),
          ),
        ),
      ),
      secondaryAction: MergeSemantics(
        child: Semantics(
          identifier: recordAgainIdentifier,
          child: TextButton(
            onPressed: cubit.recordAgain,
            child: Text(l10n.voiceRecordAgain),
          ),
        ),
      ),
      child: OnboardingSectionScope(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: context.appSpacing.xlg,
          children: [for (final step in gaps) OnboardingView.question(step)],
        ),
      ),
    );
  }
}
