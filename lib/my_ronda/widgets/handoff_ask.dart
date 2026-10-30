import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/my_ronda/cubit/this_week_cubit.dart';
import 'package:ronda/my_ronda/widgets/this_week_labels.dart';
import 'package:ronda_repository/ronda_repository.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// "¿Abrís vos?" on the Mi ronda card, while it is open to this member: the
/// cola is told who can't come, the others that nobody opens yet, then what
/// opening is, with [Sí, abro yo] [Hoy no puedo]. A rule in code asks it
/// (`functions/handoff.py`), never the model.
class const HandoffAskSection({
  /// The question.
  required final HandoffAsk ask,
  super.key,
}) extends StatelessWidget {
  /// Maestro's handles on the two answers.
  static const yesIdentifier = 'handoff.yes';
  static const noIdentifier = 'handoff.no';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.appSpacing;
    final textTheme = Theme.of(context).textTheme;
    final state = context.watch<ThisWeekCubit>().state;
    final cubit = context.read<ThisWeekCubit>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: spacing.xs,
      children: [
        Semantics(
          header: true,
          child: Text(l10n.handoffTitle, style: textTheme.titleSmall),
        ),
        Text(l10n.handoffQuestion(ask), style: textTheme.bodyLarge),
        Text(l10n.openingWords(ask.hour), style: textTheme.bodyMedium),
        if (state.actionFailure case final reason?)
          NoteBanner(
            variant: NoteBannerVariant.warning,
            message: reason == HostsFailureReason.passed
                ? l10n.handoffPassed
                : l10n.weekActionError,
          ),
        Wrap(
          spacing: spacing.sm,
          runSpacing: spacing.xs,
          children: [
            MergeSemantics(
              child: Semantics(
                identifier: yesIdentifier,
                child: FilledButton(
                  onPressed: state.acting
                      ? null
                      : () => cubit.handoffAnswered(yes: true),
                  child: Text(l10n.handoffYes),
                ),
              ),
            ),
            MergeSemantics(
              child: Semantics(
                identifier: noIdentifier,
                child: OutlinedButton(
                  onPressed: state.acting
                      ? null
                      : () => cubit.handoffAnswered(yes: false),
                  child: Text(l10n.handoffNo),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
