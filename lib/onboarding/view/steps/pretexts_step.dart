import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/onboarding/onboarding.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// "¿Qué te gustaría hacer?": one or more pretexts.
class const PretextsStep({super.key}) extends StatelessWidget {
  /// Prefix of every chip's semantics identifier.
  static const identifier = 'onboarding.pretexts';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pretexts = context.select<OnboardingCubit, Set<Pretext>>(
      (cubit) => cubit.state.pretexts,
    );
    return OnboardingQuestion(
      step: OnboardingStep.pretexts,
      title: l10n.pretextsTitle,
      body: l10n.pretextsBody,
      child: ChipPicker(
        identifier: identifier,
        options: [
          for (final pretext in Pretext.values)
            ChipPickerOption(value: pretext.name, label: l10n.pretext(pretext)),
        ],
        selected: {for (final pretext in pretexts) pretext.name},
        onChanged: (names) => context.read<OnboardingCubit>().pretextsChanged({
          for (final name in names) Pretext.values.byName(name),
        }),
      ),
    );
  }
}
