import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ronda/app/widgets/feedback.dart';
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
///
/// Each pick is a commit: felt on the tap, a progress ring on the pressed
/// choice while it saves, and the list's new state swapped in
/// ([RondaSwap]) and read out.
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
                RondaSwap(
                  layoutBuilder: topStartSwapLayout,
                  child: Column(
                    key: ValueKey(waiting.status),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: spacing.sm,
                    children: switch (waiting.status) {
                      WaitingStatus.didntFill => _didntFill(
                        context,
                        state,
                        waiting,
                      ),
                      WaitingStatus.joined => [
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            l10n.seguimosJoinDone(
                              l10n.dayDate(
                                waiting.nearby?.next ?? waiting.start,
                              ),
                            ),
                            style: textTheme.bodyLarge,
                          ),
                        ),
                      ],
                      WaitingStatus.full => [
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            l10n.waitingFull(
                              waiting.threshold,
                              l10n.dayDate(waiting.start),
                            ),
                            style: textTheme.bodyLarge,
                          ),
                        ),
                      ],
                      WaitingStatus.open => _open(context, waiting),
                    },
                  ),
                ),
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

  List<Widget> _didntFill(
    BuildContext context,
    WaitingState state,
    Waiting waiting,
  ) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final cubit = context.read<WaitingCubit>();

    Widget choice(
      WaitlistChoice pick,
      String identifier,
      String label,
      String detail,
      VoidCallback onPressed,
    ) {
      final pressed = state.saving == pick;
      return MergeSemantics(
        child: Semantics(
          identifier: identifier,
          child: IgnorePointer(
            ignoring: pressed,
            child: OutlinedButton(
              onPressed: switch (state.saving) {
                null => RondaHaptics.onCommit(onPressed),
                _ when pressed => () {},
                _ => null,
              },
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: context.appSpacing.xs),
                child: Column(
                  children: [
                    BusyLabel(label, busy: pressed),
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
        ),
      );
    }

    return [
      Text(
        l10n.waitingDidntFillTitle(waiting.threshold),
        style: textTheme.headlineSmall,
      ),
      Text(l10n.seguimosDidntFillAsk, style: textTheme.bodyMedium),
      if (waiting.nearby case final nearby?)
        choice(
          WaitlistChoice.join,
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
        WaitlistChoice.wait,
        waitIdentifier,
        l10n.seguimosWait,
        l10n.seguimosWaitDetail(
          l10n.dayDate(waiting.deadline),
          l10n.dayDate(waiting.start),
        ),
        cubit.waitTapped,
      ),
      if (state.saving != null) StatusLine(l10n.myRondaChoiceSaving),
    ];
  }
}
