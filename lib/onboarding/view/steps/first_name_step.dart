import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/onboarding/onboarding.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// "¿Cómo te llamás?": the first name only, validated as a [FirstName].
///
/// The field reports every change to the cubit; "Seguir" and the save read
/// the validated value from state, never from the field.
class const FirstNameStep({super.key}) extends StatelessWidget {
  /// Maestro's handle on the name field.
  static const identifier = 'onboarding.firstName';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final firstName = context.select<OnboardingCubit, FirstName>(
      (cubit) => cubit.state.firstName,
    );
    return OnboardingQuestion(
      step: OnboardingStep.firstName,
      title: l10n.firstNameTitle,
      body: l10n.firstNameBody,
      child: FirstNameField(
        identifier: identifier,
        value: firstName,
        autofocus: true,
        onChanged: context.read<OnboardingCubit>().firstNameChanged,
        onSubmitted: (_) => context.read<OnboardingCubit>().next(),
      ),
    );
  }
}
