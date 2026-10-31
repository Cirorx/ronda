import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ronda/app/widgets/feedback.dart';
import 'package:ronda/attendance/widgets/roll_link.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/my_ronda/cubit/this_week_cubit.dart';
import 'package:ronda/my_ronda/widgets/answer_bar.dart';
import 'package:ronda/my_ronda/widgets/despues_section.dart';
import 'package:ronda/my_ronda/widgets/handoff_ask.dart';
import 'package:ronda/my_ronda/widgets/this_week_labels.dart';
import 'package:ronda_repository/ronda_repository.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// This week's card: the ronda's line with its hour, where it meets (or
/// "Lugar y hora a confirmar"), who opens and closes, "¿Venís?" with "Voy"
/// and "Esta no" (or the answer and "Cambiar mi respuesta"), and who's
/// coming: the yeses by first name, their role and what they bring, only
/// counts for the rest. The anfitrión and the cola also get "¿Quién vino
/// hoy?" once the meeting's roll exists. It carries the monthly turns,
/// "¿Abrís vos?" while it is open to this member, and the después.
///
/// The answer is the card's one moment of motion: the question gives way
/// to "Vas" on a [RondaSwap], someone joining "Quiénes van" grows into the
/// list on a spring, and the counts swap with them.
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
    final Key answerKey;
    if (state.asks) {
      answerKey = const ValueKey('asks');
      answer = AnswerBar(
        identifier: rsvpIdentifier,
        question: l10n.thisWeekQuestion,
        message: item == null ? null : l10n.thisWeekYourTurn(item),
        yesLabel: l10n.thisWeekYes,
        noLabel: l10n.thisWeekNo,
        onYes: cubit.yesTapped,
        onNo: cubit.noTapped,
        savingLabel: l10n.thisWeekSaving,
        pending: switch (state.answering) {
          RsvpAnswer.yes => AnswerSide.yes,
          RsvpAnswer.no => AnswerSide.no,
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: spacing.xxs,
                children: [
                  Text(l10n.rondaLine(week), style: textTheme.titleMedium),
                  Text(l10n.placeLine(week), style: textTheme.bodyLarge),
                  if (l10n.hostsLine(week, uid: uid) case final hosts?)
                    Text(hosts, style: textTheme.bodyMedium),
                  if (l10n.turnsLine(week) case final turns?)
                    Text(turns, style: textTheme.bodySmall),
                ],
              ),
              if (week.handoffAsk case final ask?) HandoffAskSection(ask: ask),
              DespuesSection(week: week, uid: uid),
              if (state.answerFailed)
                NoteBanner(
                  variant: NoteBannerVariant.warning,
                  message: l10n.thisWeekSaveError,
                ),
              RondaSwap(
                layoutBuilder: topStartSwapLayout,
                child: KeyedSubtree(key: answerKey, child: answer),
              ),
              if (week.week != null) ..._coming(context, week),
              if (week.week case final meeting?
                  when uid == week.anfitrion?.uid || uid == week.cola?.uid)
                RollLink(rondaId: week.rondaId, week: meeting),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _coming(BuildContext context, ThisWeek week) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final counts = l10n.counts(
      week,
      answered: week.myAnswer != null || week.pausedUntil != null,
    );
    return [
      Semantics(
        header: true,
        child: Text(l10n.thisWeekWhoTitle, style: textTheme.titleSmall),
      ),
      if (week.going.isNotEmpty) _Going(week: week, uid: uid),
      RondaSwap(
        layoutBuilder: topStartSwapLayout,
        child: Text(counts, key: ValueKey(counts), style: textTheme.bodyMedium),
      ),
    ];
  }
}

/// "Quiénes van": a row per yes. Someone who joins while the card is up
/// grows into the list ([_Arriving]); the rows there from the start don't
/// move.
class const _Going({required final ThisWeek week, required final String uid})
    extends StatefulWidget {
  @override
  State<_Going> createState() => _GoingState();
}

class _GoingState extends State<_Going> {
  Set<String> _arriving = const {};

  @override
  void didUpdateWidget(_Going oldWidget) {
    super.didUpdateWidget(oldWidget);
    final before = {for (final person in oldWidget.week.going) person.uid};
    _arriving = {
      for (final person in widget.week.going)
        if (!before.contains(person.uid)) person.uid,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final week = widget.week;
    return Column(
      children: [
        for (final (index, person) in week.going.indexed)
          _Arriving(
            key: ValueKey(person.uid),
            arriving: _arriving.contains(person.uid),
            child: PersonRow(
              initial: person.firstName.isEmpty
                  ? '?'
                  : person.firstName.characters.first.toUpperCase(),
              name: person.uid == widget.uid
                  ? l10n.thisWeekYou
                  : person.firstName,
              detail: l10n.roleAndBrings(week, person),
              isYou: person.uid == widget.uid,
              showDivider: index < week.going.length - 1,
            ),
          ),
      ],
    );
  }
}

/// A seat filling: a row that [arriving] opens from nothing to its height
/// and fades in on the standard spring; any other row is simply there.
class const _Arriving({
  required final bool arriving,
  required final Widget child,
  super.key,
}) extends StatefulWidget {
  @override
  State<_Arriving> createState() => _ArrivingState();
}

class _ArrivingState extends State<_Arriving> {
  late double _shown = widget.arriving ? 0 : 1;

  @override
  void initState() {
    super.initState();
    if (!widget.arriving) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _shown = 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SpringBuilder(
      value: _shown,
      builder: (context, value, child) {
        final shown = value.clamp(0.0, 1.0);
        return ClipRect(
          child: Align(
            alignment: AlignmentDirectional.topStart,
            heightFactor: shown,
            child: Opacity(opacity: shown, child: child),
          ),
        );
      },
      child: widget.child,
    );
  }
}
