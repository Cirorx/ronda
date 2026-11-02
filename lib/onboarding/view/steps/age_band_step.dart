import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/onboarding/onboarding.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// "¿Qué edad tenés, más o menos?": a band, never a birth date.
class const AgeBandStep({super.key}) extends StatelessWidget {
  /// Prefix of every chip's semantics identifier.
  static const identifier = 'onboarding.ageBand';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ageBand = context.select<OnboardingCubit, AgeBand?>(
      (cubit) => cubit.state.ageBand,
    );
    return OnboardingQuestion(
      step: OnboardingStep.ageBand,
      title: l10n.ageBandTitle,
      body: l10n.ageBandBody,
      child: AgeBandPicker(
        identifier: identifier,
        selected: ageBand,
        onChanged: context.read<OnboardingCubit>().ageBandChanged,
      ),
    );
  }
}
