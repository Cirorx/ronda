import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/my_ronda/cubit/this_week_cubit.dart';
import 'package:ronda/my_ronda/widgets/this_week_labels.dart';
import 'package:ronda_repository/ronda_repository.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// This week's card: the ronda's line, "¿Venís?" with "Voy" and "Esta no"
/// (or the answer and "Cambiar mi respuesta"), and who's coming: the yeses
/// by first name and what they bring, only counts for the rest.
class const ThisWeekCard({
  required final ThisWeekState state,
  required final String uid,
  super.key,
}) extends StatelessWidget {
  /// Maestro's handles: the card, the RsvpBar's prefix (`rsvp.yes`,
  /// `rsvp.no`) and "Cambiar mi respuesta".
  static const identifier = 'thisWeek';
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

    final Widget answer;
    if (state.asks) {
      answer = RsvpBar(
        identifier: rsvpIdentifier,
        question: l10n.thisWeekQuestion,
        message: item == null ? null : l10n.thisWeekYourTurn(item),
        yesLabel: l10n.thisWeekYes,
        noLabel: l10n.thisWeekNo,
        onYes: cubit.yesTapped,
        onNo: cubit.noTapped,
      );
    } else {
      final going = week.myAnswer == RsvpAnswer.yes;
      answer = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: spacing.xs,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              going
                  ? (item == null
                        ? l10n.thisWeekGoing
                        : l10n.thisWeekGoingBring(item))
                  : l10n.thisWeekNotGoing,
              style: textTheme.headlineSmall,
            ),
          ),
          if (!going && week.pausedUntil != null)
            Text(
              l10n.thisWeekPausedUntil(l10n.shortDate(week.pausedUntil!)),
              style: textTheme.bodyMedium,
            ),
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

    return Semantics(
      container: true,
      identifier: identifier,
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: spacing.md,
            children: [
              Text(l10n.rondaLine(week), style: textTheme.titleMedium),
              if (state.answering) const LinearProgressIndicator(),
              if (state.answerFailed)
                NoteBanner(
                  variant: NoteBannerVariant.warning,
                  message: l10n.thisWeekSaveError,
                ),
              answer,
              if (week.week != null) ..._coming(context, week),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _coming(BuildContext context, ThisWeek week) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    return [
      Semantics(
        header: true,
        child: Text(l10n.thisWeekWhoTitle, style: textTheme.titleSmall),
      ),
      if (week.going.isNotEmpty)
        Column(
          children: [
            for (final (index, person) in week.going.indexed)
              PersonRow(
                initial: person.firstName.isEmpty
                    ? '?'
                    : person.firstName.characters.first.toUpperCase(),
                name: person.uid == uid ? l10n.thisWeekYou : person.firstName,
                detail: l10n.bringsDetail(person.brings),
                isYou: person.uid == uid,
                showDivider: index < week.going.length - 1,
              ),
          ],
        ),
      Text(
        l10n.counts(
          week,
          answered: week.myAnswer != null || week.pausedUntil != null,
        ),
        style: textTheme.bodyMedium,
      ),
    ];
  }
}
