import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ronda/onboarding/cubit/onboarding_cubit.dart';
import 'package:ronda/onboarding/widgets/onboarding_next_button.dart';
import 'package:ronda/onboarding/widgets/onboarding_step_layout.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// {@template onboarding_question}
/// One question of onboarding: its number among the questions, the back
/// button (except on the first, unless it was opened from the read-back)
/// and "Seguir".
/// {@endtemplate}
class const OnboardingQuestion({
  /// Which question this is.
  required final OnboardingStep step,

  /// The question.
  required final String title,

  /// The picker or field that answers it.
  required final Widget child,

  /// The text under the question.
  final String? body,

  /// A short line above the question ("Opcional").
  final String? overline,

  /// An optional action under "Seguir" ("Saltear").
  final Widget? secondaryAction,
  super.key,
}) extends StatelessWidget {
  /// {@macro onboarding_question}
  this;

  @override
  Widget build(BuildContext context) {
    final editingFromReview = context.select<OnboardingCubit, bool>(
      (cubit) => cubit.state.editingFromReview,
    );
    final canGoBack = editingFromReview || step.index > 0;
    return OnboardingStepLayout(
      title: title,
      body: body,
      overline: overline,
      questionNumber: OnboardingStep.questions.indexOf(step) + 1,
      questionCount: OnboardingStep.questions.length,
      onBack: canGoBack ? () => context.read<OnboardingCubit>().back() : null,
      primaryAction: const OnboardingNextButton(),
      secondaryAction: secondaryAction,
      child: child,
    );
  }
}
