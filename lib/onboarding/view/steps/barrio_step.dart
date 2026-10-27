import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/onboarding/onboarding.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// "¿En qué barrio estás?": only the barrio, never an address.
class const BarrioStep({super.key}) extends StatelessWidget {
  /// Prefix of every chip's semantics identifier.
  static const identifier = 'onboarding.barrio';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final barrio = context.select<OnboardingCubit, Barrio?>(
      (cubit) => cubit.state.barrio,
    );
    return OnboardingQuestion(
      step: OnboardingStep.barrio,
      title: l10n.barrioTitle,
      body: l10n.barrioBody,
      child: ChipPicker(
        identifier: identifier,
        multiSelect: false,
        options: [
          for (final barrio in Barrio.values)
            ChipPickerOption(value: barrio.name, label: l10n.barrio(barrio)),
        ],
        selected: {?barrio?.name},
        onChanged: (names) => context.read<OnboardingCubit>().barrioChanged(
          Barrio.values.byName(names.single),
        ),
      ),
    );
  }
}
