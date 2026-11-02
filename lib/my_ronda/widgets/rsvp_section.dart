import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/my_ronda/cubit/this_week_cubit.dart';
import 'package:ronda/my_ronda/widgets/this_week_labels.dart';
import 'package:ronda_repository/ronda_repository.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// "¿Venís?" on this week's card: "Voy" and "Esta no" with what the member
/// brings while the question is open, or their answer ("Vas. Llevá el pan.")
/// with "Cambiar mi respuesta". The answer is the card's one moment of
/// motion: the question gives way to the answer on a [RondaSwap].
///
/// The same section stands on the template card and on the card the
/// organiser composed, so a tap always goes through [ThisWeekCubit].
class const RsvpSection({required final ThisWeekState state, super.key})
    extends StatelessWidget {
  /// Maestro's handles: the RsvpBar's prefix (`rsvp.yes`, `rsvp.no`) and
  /// "Cambiar mi respuesta".
  static const rsvpIdentifier = 'rsvp';
  static const changeIdentifier = 'rsvp.change';

  @override
  Widget build(BuildContext context) {
    final week = state.week!;
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final spacing = context.appSpacing;
    final cubit = context.read<ThisWeekCubit>();
    final item = l10n.bringItem(week.myBrings);
    final turn = l10n.yourTurn(week.myBrings);
    final rainTurn = item == null && turn != null;

    final Widget answer;
    final Key answerKey;
    if (state.asks) {
      answerKey = const ValueKey('asks');
      answer = RsvpBar(
        identifier: rsvpIdentifier,
        question: l10n.thisWeekQuestion,
        message: turn,
        yesLabel: l10n.thisWeekYes,
        noLabel: l10n.thisWeekNo,
        onYes: cubit.yesTapped,
        onNo: cubit.noTapped,
        savingLabel: l10n.thisWeekSaving,
        pending: switch (state.answering) {
          RsvpAnswer.yes => RsvpBarAnswer.yes,
          RsvpAnswer.no => RsvpBarAnswer.no,
          null => null,
        },
      );
    } else {
      final going = week.myAnswer == RsvpAnswer.yes;
      answerKey = ValueKey((going, week.pausedUntil));
      answer = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: spacing.xs,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              going
                  ? switch (item) {
                      final item? => l10n.thisWeekGoingBring(item),
                      null when rainTurn => l10n.thisWeekGoingRain,
                      null => l10n.thisWeekGoing,
                    }
                  : l10n.thisWeekNotGoing,
              style: textTheme.headlineSmall,
            ),
          ),
          if (!going && week.pausedUntil != null)
            Text(
              l10n.thisWeekPausedUntil(l10n.shortDate(week.pausedUntil!)),
              style: textTheme.bodyMedium,
            ),
          if (state.answering != null) StatusLine(l10n.thisWeekSaving),
          MergeSemantics(
            child: Semantics(
              identifier: changeIdentifier,
              child: TextButton(
                onPressed: cubit.changeTapped,
                child: Text(l10n.thisWeekChange),
              ),
            ),
          ),
        ],
      );
    }

    return RondaSwap(
      layoutBuilder: RondaSwap.topStartLayout,
      child: KeyedSubtree(key: answerKey, child: answer),
    );
  }
}
