import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:needs_repository/needs_repository.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/onboarding/onboarding.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// The read-back: every answer with its "Cambiar", what stays on the phone,
/// and "Está bien, guardalo".
class const ReviewStep({super.key}) extends StatelessWidget {
  /// Prefix of every "Cambiar" action's semantics identifier.
  static const identifier = 'onboarding.review';

  /// Maestro's handle on "Está bien, guardalo".
  static const saveIdentifier = 'onboarding.save';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.appSpacing;
    final state = context.watch<OnboardingCubit>().state;
    final cubit = context.read<OnboardingCubit>();
    final saving =
        state.status == OnboardingStatus.saving ||
        state.status == OnboardingStatus.saved;

    ReadBackField field(
      OnboardingStep step,
      String label,
      String value,
      String editLabel,
    ) => ReadBackField(
      id: step.name,
      label: label,
      value: value,
      editSemanticsLabel: editLabel,
      onEdit: () => cubit.edit(step),
    );

    return OnboardingStepLayout(
      title: l10n.reviewTitle,
      body: l10n.reviewBody,
      onBack: cubit.back,
      primaryAction: MergeSemantics(
        child: Semantics(
          identifier: saveIdentifier,
          child: FilledButton(
            onPressed: saving ? null : cubit.save,
            child: Text(l10n.reviewSave),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: spacing.md,
        children: [
          ReadBackCard(
            identifier: identifier,
            editLabel: l10n.reviewEdit,
            fields: [
              field(
                OnboardingStep.firstName,
                l10n.reviewFirstName,
                state.firstName.name,
                l10n.reviewEditFirstName,
              ),
              field(
                OnboardingStep.ageBand,
                l10n.reviewAgeBand,
                switch (state.ageBand) {
                  final band? => l10n.ageBand(band),
                  null => '',
                },
                l10n.reviewEditAgeBand,
              ),
              field(
                OnboardingStep.barrio,
                l10n.reviewBarrio,
                switch (state.barrio) {
                  final barrio? => l10n.barrio(barrio),
                  null => '',
                },
                l10n.reviewEditBarrio,
              ),
              field(
                OnboardingStep.pretexts,
                l10n.reviewPretexts,
                [
                  for (final pretext in Pretext.values)
                    if (state.pretexts.contains(pretext)) l10n.pretext(pretext),
                ].join(', '),
                l10n.reviewEditPretexts,
              ),
              field(
                OnboardingStep.slots,
                l10n.reviewSlots,
                [
                  for (final day in SlotDay.values)
                    for (final band in SlotBand.values)
                      if (state.slots.contains(Slot(day, band)))
                        l10n.slot(Slot(day, band)),
                ].join(', '),
                l10n.reviewEditSlots,
              ),
              field(
                OnboardingStep.brings,
                l10n.reviewBrings,
                [
                  for (final bring in Bring.values)
                    if (state.brings.contains(bring)) l10n.bring(bring),
                ].join(', '),
                l10n.reviewEditBrings,
              ),
              field(
                OnboardingStep.needs,
                l10n.reviewNeeds,
                state.needs.isEmpty
                    ? l10n.reviewNoNeeds
                    : [
                        for (final need in Need.values)
                          if (state.needs.contains(need)) l10n.need(need),
                      ].join(', '),
                l10n.reviewEditNeeds,
              ),
            ],
          ),
          NoteBanner(
            variant: NoteBannerVariant.keptOnPhone,
            icon: Icons.smartphone,
            message: l10n.reviewNeedsKeptOnPhone,
          ),
          if (state.status == OnboardingStatus.failure)
            NoteBanner(
              variant: NoteBannerVariant.warning,
              message: l10n.reviewSaveError,
            ),
        ],
      ),
    );
  }
}
