import 'package:ronda/attendance/widgets/roll_link.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/my_ronda/agent_card/agent_card_surface.dart';
import 'package:ronda/my_ronda/cubit/this_week_cubit.dart';
import 'package:ronda/my_ronda/widgets/despues_section.dart';
import 'package:ronda/my_ronda/widgets/handoff_ask.dart';
import 'package:ronda/my_ronda/widgets/rsvp_section.dart';
import 'package:ronda/my_ronda/widgets/this_week_labels.dart';
import 'package:ronda/my_ronda/widgets/who_is_going.dart';
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
/// With the ronda's switch on and a card the organiser composed for this
/// week ([ThisWeek.agentCard]), its notices and "¿Venís?" are drawn from
/// that card ([AgentCardSurface]); whatever can't be drawn falls back to
/// the same [RsvpSection] the template shows.
///
/// The answer is the card's one moment of motion: the question gives way
/// to "Vas" on a [RondaSwap], someone joining "Quiénes van" grows into the
/// list on a spring, and the counts swap with them.
class const ThisWeekCard({
  required final ThisWeekState state,
  required final String uid,

  /// Whether "Quiénes van" is on the card; a desktop window shows it beside
  /// the card instead.
  final bool showWhoIsGoing = true,

  /// A line the member chose to bring from their cuaderno, drawn on their
  /// own card as a reminder; nothing when `null`.
  final Widget? reminder,
  super.key,
}) extends StatelessWidget {
  /// Maestro's handles: the card, the RsvpBar's prefix (`rsvp.yes`,
  /// `rsvp.no`) and "Cambiar mi respuesta".
  static const identifier = 'thisWeek';
  static const String rsvpIdentifier = RsvpSection.rsvpIdentifier;
  static const String changeIdentifier = RsvpSection.changeIdentifier;

  @override
  Widget build(BuildContext context) {
    final week = state.week!;
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final spacing = context.appSpacing;

    Widget rsvp(BuildContext _) => RsvpSection(state: state);

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
              if (week.agentCard case final card?)
                AgentCardSurface(card: card, rsvp: rsvp, fallback: rsvp)
              else
                rsvp(context),
              if (week.week != null && showWhoIsGoing)
                WhoIsGoing(week: week, uid: uid),
              ?reminder,
              if (week.week case final meeting?
                  when uid == week.anfitrion?.uid || uid == week.cola?.uid)
                RollLink(rondaId: week.rondaId, week: meeting),
            ],
          ),
        ),
      ),
    );
  }
}
