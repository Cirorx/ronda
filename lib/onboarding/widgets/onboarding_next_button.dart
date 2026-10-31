import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/onboarding/cubit/onboarding_cubit.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// "Seguir": on past the open page, enabled once every question on it is
/// answered.
class const OnboardingNextButton({
  /// The questions on the open page; the open step alone when `null`.
  final List<OnboardingStep>? page,
  super.key,
}) extends StatelessWidget {
  /// Maestro's handle on "Seguir".
  static const identifier = 'onboarding.next';

  @override
  Widget build(BuildContext context) {
    // A page of one question is the open step: "Seguir" as ever.
    final page = (this.page?.length ?? 0) > 1 ? this.page : null;
    final canContinue = context.select<OnboardingCubit, bool>(
      (cubit) => page == null
          ? cubit.state.canContinue
          : page.every(cubit.state.isAnswered),
    );
    return MergeSemantics(
      child: Semantics(
        identifier: identifier,
        child: FilledButton(
          onPressed: canContinue
              ? () {
                  final cubit = context.read<OnboardingCubit>();
                  page == null ? cubit.next() : cubit.nextAfter(page);
                }
              : null,
          child: Text(context.l10n.onboardingNext),
        ),
      ),
    );
  }
}
