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
          SlotGrid(
            identifier: identifier,
            dayLabels: [for (final day in SlotDay.values) l10n.slotDay(day)],
            bandLabels: [
              for (final band in SlotBand.values) l10n.slotBand(band),
            ],
            cellSemanticsLabel: (day, band) =>
                l10n.slot(Slot(SlotDay.values[day], SlotBand.values[band])),
            selected: {
              for (final slot in slots)
                (day: slot.day.index, band: slot.band.index),
            },
            onChanged: (cells) => context.read<OnboardingCubit>().slotsChanged({
              for (final cell in cells)
                Slot(SlotDay.values[cell.day], SlotBand.values[cell.band]),
            }),
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
