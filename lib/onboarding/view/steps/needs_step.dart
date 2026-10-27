import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:needs_repository/needs_repository.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/onboarding/onboarding.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// "¿Hay algo que te complique ir?": optional, and kept on this phone only.
class const NeedsStep({super.key}) extends StatelessWidget {
  /// Prefix of every switch's semantics identifier.
  static const identifier = 'onboarding.needs';

  /// Maestro's handle on "Saltear".
  static const skipIdentifier = 'onboarding.skip';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final spacing = context.appSpacing;
    final needs = context.select<OnboardingCubit, Set<Need>>(
      (cubit) => cubit.state.needs,
    );
    return OnboardingQuestion(
      step: OnboardingStep.needs,
      overline: l10n.needsOptional,
      title: l10n.needsTitle,
      body: l10n.needsBody,
      secondaryAction: MergeSemantics(
        child: Semantics(
          identifier: skipIdentifier,
          child: TextButton(
            onPressed: () => context.read<OnboardingCubit>().needsSkipped(),
            child: Text(l10n.onboardingSkip),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NoteBanner(
            variant: NoteBannerVariant.keptOnPhone,
            icon: Icons.smartphone,
            message: l10n.needsKeptOnPhone,
          ),
          SizedBox(height: spacing.sm),
          for (final need in Need.values)
            MergeSemantics(
              child: Semantics(
                identifier: '$identifier.${need.name}',
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.need(need)),
                  value: needs.contains(need),
                  onChanged: (marked) => context
                      .read<OnboardingCubit>()
                      .needToggled(need, marked: marked),
                ),
              ),
            ),
          SizedBox(height: spacing.sm),
          Text(
            l10n.needsChangeLater,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
