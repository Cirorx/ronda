import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/onboarding/onboarding.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// "¿Qué podés llevar o enseñar?": one thing is enough, and "Tengo ganas"
/// counts.
class const BringsStep({super.key}) extends StatelessWidget {
  /// Prefix of every chip's semantics identifier.
  static const identifier = 'onboarding.brings';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final brings = context.select<OnboardingCubit, Set<Bring>>(
      (cubit) => cubit.state.brings,
    );
    return OnboardingQuestion(
      step: OnboardingStep.brings,
      title: l10n.bringsTitle,
      body: l10n.bringsBody,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: context.appSpacing.lg,
        children: [
          ChipPicker(
            identifier: identifier,
            options: [
              for (final bring in Bring.values)
                ChipPickerOption(value: bring.name, label: l10n.bring(bring)),
            ],
            selected: {for (final bring in brings) bring.name},
            onChanged: (names) => context.read<OnboardingCubit>().bringsChanged(
              {for (final name in names) Bring.values.byName(name)},
            ),
          ),
          Text(
            l10n.bringsNote,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
