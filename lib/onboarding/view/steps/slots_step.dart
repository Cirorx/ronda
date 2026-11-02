import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/onboarding/onboarding.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// "¿Cuándo podés?": every day and time band that works.
class const SlotsStep({super.key}) extends StatelessWidget {
  /// Prefix of every cell's semantics identifier.
  static const identifier = 'onboarding.slots';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final slots = context.select<OnboardingCubit, Set<Slot>>(
      (cubit) => cubit.state.slots,
    );
    return OnboardingQuestion(
      step: OnboardingStep.slots,
      title: l10n.slotsTitle,
      body: l10n.slotsBody,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: context.appSpacing.md,
        children: [
          SlotsPicker(
            identifier: identifier,
            selected: slots,
            onChanged: context.read<OnboardingCubit>().slotsChanged,
          ),
          Text(
            l10n.slotsBands,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
