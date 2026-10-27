import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/onboarding/cubit/onboarding_cubit.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// "Seguir": on to the next question, enabled once the open one is
/// answered.
class const OnboardingNextButton({super.key}) extends StatelessWidget {
  /// Maestro's handle on "Seguir".
  static const identifier = 'onboarding.next';

  @override
  Widget build(BuildContext context) {
    final canContinue = context.select<OnboardingCubit, bool>(
      (cubit) => cubit.state.canContinue,
    );
    return MergeSemantics(
      child: Semantics(
        identifier: identifier,
        child: FilledButton(
          onPressed: canContinue
              ? () => context.read<OnboardingCubit>().next()
              : null,
          child: Text(context.l10n.onboardingNext),
        ),
      ),
    );
  }
}
