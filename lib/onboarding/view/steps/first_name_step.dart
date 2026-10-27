import 'package:flutter/services.dart';
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
    final error = firstName.isPure ? null : firstName.error;
    return OnboardingQuestion(
      step: OnboardingStep.firstName,
      title: l10n.firstNameTitle,
      body: l10n.firstNameBody,
      child: MergeSemantics(
        child: Semantics(
          identifier: identifier,
          child: TextFormField(
            initialValue: firstName.value,
            autofocus: true,
            autofillHints: const [AutofillHints.givenName],
            keyboardType: TextInputType.name,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            inputFormatters: [
              LengthLimitingTextInputFormatter(FirstName.maxLength),
            ],
            decoration: InputDecoration(
              labelText: l10n.firstNameLabel,
              errorText: switch (error) {
                FirstNameValidationError.empty => l10n.firstNameErrorEmpty,
                FirstNameValidationError.tooLong => l10n.firstNameErrorTooLong(
                  FirstName.maxLength,
                ),
                FirstNameValidationError.invalid => l10n.firstNameErrorInvalid,
                null => null,
              },
            ),
            onChanged: context.read<OnboardingCubit>().firstNameChanged,
            onFieldSubmitted: (_) => context.read<OnboardingCubit>().next(),
          ),
        ),
      ),
    );
  }
}
