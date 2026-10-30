import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/my_ronda/cubit/waiting_cubit.dart';
import 'package:ronda/my_ronda/widgets/bench_labels.dart';
import 'package:ronda/my_ronda/widgets/this_week_labels.dart';
import 'package:ronda_repository/ronda_repository.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// The waiting-list card on Mi ronda before a group exists: "Con vos son 5
/// de 6. Falta uno.", the deadline and the start, and what happens if it
/// doesn't fill; once a round didn't fill, "Esta vez no llegamos a 6" with
/// "Sumarte a otro ya" and "Esperar dos semanas más", each with its date.
/// Counts only, never a name. Reads the [WaitingCubit] above.
class const WaitingCard({super.key}) extends StatelessWidget {
  /// Maestro's handles: the card and the two choices.
  static const identifier = 'waiting';
  static const joinIdentifier = 'waiting.join';
  static const waitIdentifier = 'waiting.wait';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<WaitingCubit>().state;
    final waiting = state.waiting;
    if (state.status != WaitingCardStatus.ready || waiting == null) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final spacing = context.appSpacing;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(top: spacing.lg),
      child: Semantics(
        container: true,
        identifier: identifier,
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(spacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: spacing.sm,
              children: [
                if (state.saving) const LinearProgressIndicator(),
                if (state.saveFailed)
                  NoteBanner(
                    variant: NoteBannerVariant.warning,
                    message: l10n.thisWeekSaveError,
                  ),
                Semantics(
                  header: true,
                  child: Text(l10n.waitingTitle, style: textTheme.titleMedium),
                ),
                Text(l10n.waitingLine(waiting), style: textTheme.bodyMedium),
                ...switch (waiting.status) {
                  WaitingStatus.didntFill => _didntFill(context, waiting),
                  WaitingStatus.joined => [
                    Text(
                      l10n.seguimosJoinDone(
                        l10n.dayDate(waiting.nearby?.next ?? waiting.start),
                      ),
                      style: textTheme.bodyLarge,
                    ),
                  ],
                  WaitingStatus.full => [
                    Text(
                      l10n.waitingFull(
                        waiting.threshold,
                        l10n.dayDate(waiting.start),
                      ),
                      style: textTheme.bodyLarge,
                    ),
                  ],
                  WaitingStatus.open => _open(context, waiting),
                },
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _open(BuildContext context, Waiting waiting) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    return [
      Text(
        [
          l10n.waitingWithYou(waiting.count, waiting.threshold),
          if (waiting.count > 1) l10n.waitingMissing(waiting.missing),
        ].join(' '),
        style: textTheme.headlineSmall,
      ),
      Text(
        l10n.waitingIfJoin(
          waiting.missing,
          l10n.dayDate(waiting.deadline),
          l10n.dayDate(waiting.start),
        ),
        style: textTheme.bodyLarge,
      ),
      Text(l10n.waitingIfNot, style: textTheme.bodyMedium),
    ];
  }

  List<Widget> _didntFill(BuildContext context, Waiting waiting) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final cubit = context.read<WaitingCubit>();

    Widget choice(
      String identifier,
      String label,
      String detail,
      VoidCallback onPressed,
    ) => MergeSemantics(
      child: Semantics(
        identifier: identifier,
        child: OutlinedButton(
          onPressed: onPressed,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: context.appSpacing.xs),
            child: Column(
              children: [
                Text(label, textAlign: TextAlign.center),
                Text(
                  detail,
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return [
      Text(
        l10n.waitingDidntFillTitle(waiting.threshold),
        style: textTheme.headlineSmall,
      ),
      Text(l10n.seguimosDidntFillAsk, style: textTheme.bodyMedium),
      if (waiting.nearby case final nearby?)
        choice(
          joinIdentifier,
          l10n.seguimosJoin,
          l10n.seguimosJoinDetail(
            l10n.rondaLineOf(
              slotDayId: nearby.slotDayId,
              slotBandId: nearby.slotBandId,
              pretextId: nearby.pretextId,
            ),
            l10n.dayDate(nearby.next),
          ),
          cubit.joinTapped,
        ),
      choice(
        waitIdentifier,
        l10n.seguimosWait,
        l10n.seguimosWaitDetail(
          l10n.dayDate(waiting.deadline),
          l10n.dayDate(waiting.start),
        ),
        cubit.waitTapped,
      ),
    ];
  }
}
