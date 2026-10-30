import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/my_ronda/cubit/seguimos_cubit.dart';
import 'package:ronda/my_ronda/widgets/this_week_labels.dart';
import 'package:ronda_repository/ronda_repository.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// The ¿seguimos? card on Mi ronda: the private question with "Sí" and "No"
/// (or the member's own answer and "Cambiar" until the close), and once it
/// closed what came of it for this member: the season, "Gracias por
/// venir." with nearby rondas, or the "didn't fill" choices. Never a count
/// or anyone else's answer. Reads the [SeguimosCubit] above.
class const SeguimosCard({super.key}) extends StatelessWidget {
  /// Maestro's handles: the card, the question's prefix (`seguimos.yes`,
  /// `seguimos.no`), "Cambiar" and the two choices.
  static const identifier = 'seguimos';
  static const answerIdentifier = 'seguimos';
  static const changeIdentifier = 'seguimos.change';
  static const joinIdentifier = 'seguimos.join';
  static const waitIdentifier = 'seguimos.wait';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SeguimosCubit>().state;
    final seguimos = state.seguimos;
    if (state.status != SeguimosCardStatus.ready || seguimos == null) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final spacing = context.appSpacing;
    final List<Widget> body;
    if (seguimos.open) {
      body = _question(context, state, seguimos);
    } else {
      body = switch (seguimos.outcome) {
        SeguimosOutcome.season => _season(context, seguimos),
        SeguimosOutcome.gracias => _gracias(context, seguimos),
        SeguimosOutcome.didntFill => _didntFill(context, seguimos),
        null => const [],
      };
    }
    if (body.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(bottom: spacing.md),
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
                if (state.closed)
                  NoteBanner(
                    variant: NoteBannerVariant.warning,
                    message: l10n.seguimosClosed,
                  ),
                ...body,
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _question(
    BuildContext context,
    SeguimosState state,
    Seguimos seguimos,
  ) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final cubit = context.read<SeguimosCubit>();
    if (state.asks) {
      return [
        RsvpBar(
          identifier: answerIdentifier,
          question: l10n.seguimosQuestion(
            l10n.seguimosDays(seguimos.slotDayId),
          ),
          message: l10n.seguimosPrivate,
          yesLabel: l10n.seguimosYes,
          noLabel: l10n.seguimosNo,
          onYes: cubit.yesTapped,
          onNo: cubit.noTapped,
        ),
        Text(l10n.seguimosSilence, style: textTheme.bodyMedium),
      ];
    }
    return [
      Text(
        l10n.seguimosQuestion(l10n.seguimosDays(seguimos.slotDayId)),
        style: textTheme.titleMedium,
      ),
      Semantics(
        liveRegion: true,
        child: Text(
          seguimos.myAnswer == SeguimosAnswer.yes
              ? l10n.seguimosAnsweredYes
              : l10n.seguimosAnsweredNo,
          style: textTheme.headlineSmall,
        ),
      ),
      Text(l10n.seguimosPrivate, style: textTheme.bodyMedium),
      Text(l10n.seguimosChangeUntil, style: textTheme.bodyMedium),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: MergeSemantics(
          child: Semantics(
            identifier: changeIdentifier,
            child: TextButton(
              onPressed: cubit.changeTapped,
              child: Text(l10n.seguimosChange),
            ),
          ),
        ),
      ),
    ];
  }

  List<Widget> _season(BuildContext context, Seguimos seguimos) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    return [
      Semantics(
        header: true,
        child: Text(
          l10n.seguimosSeasonTitle(l10n.seguimosDays(seguimos.slotDayId)),
          style: textTheme.headlineSmall,
        ),
      ),
      if (seguimos.seasonEnd case final end?)
        Text(
          l10n.seguimosSeasonUntil(l10n.shortDate(end)),
          style: textTheme.bodyLarge,
        ),
      Text(l10n.seguimosNobodyKnows, style: textTheme.bodyMedium),
    ];
  }

  List<Widget> _gracias(BuildContext context, Seguimos seguimos) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    return [
      Semantics(
        header: true,
        child: Text(l10n.seguimosGraciasTitle, style: textTheme.headlineSmall),
      ),
      if (seguimos.alternatives.isEmpty)
        Text(l10n.seguimosGraciasNone, style: textTheme.bodyMedium)
      else ...[
        Text(l10n.seguimosGraciasNearby, style: textTheme.bodyMedium),
        for (final nearby in seguimos.alternatives)
          MergeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_line(l10n, nearby), style: textTheme.titleSmall),
                Text(
                  l10n.seguimosNearbyDetail(
                    nearby.placesLeft,
                    l10n.shortDate(nearby.next),
                  ),
                  style: textTheme.bodyMedium,
                ),
              ],
            ),
          ),
      ],
    ];
  }

  List<Widget> _didntFill(BuildContext context, Seguimos seguimos) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final cubit = context.read<SeguimosCubit>();
    final nearby = seguimos.alternatives.firstOrNull;
    final until = seguimos.waitUntil;
    final start = seguimos.waitStart;
    final waitDetail = until == null || start == null
        ? null
        : l10n.seguimosWaitDetail(l10n.shortDate(until), l10n.shortDate(start));

    Widget choice(
      String identifier,
      String label,
      String? detail,
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
                if (detail != null)
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
      Semantics(
        header: true,
        child: Text(
          l10n.seguimosDidntFillTitle(
            seguimos.floor ?? 0,
            l10n.seguimosDays(seguimos.slotDayId),
          ),
          style: textTheme.titleMedium,
        ),
      ),
      ...switch (seguimos.choice) {
        SeguimosChoice.join when nearby != null => [
          Text(
            l10n.seguimosJoinDone(l10n.shortDate(nearby.next)),
            style: textTheme.bodyLarge,
          ),
        ],
        SeguimosChoice.wait when until != null && start != null => [
          Text(
            l10n.seguimosWaitDone(l10n.shortDate(until), l10n.shortDate(start)),
            style: textTheme.bodyLarge,
          ),
        ],
        _ => [
          Text(l10n.seguimosDidntFillAsk, style: textTheme.bodyMedium),
          if (nearby != null)
            choice(
              joinIdentifier,
              l10n.seguimosJoin,
              l10n.seguimosJoinDetail(
                _line(l10n, nearby),
                l10n.shortDate(nearby.next),
              ),
              cubit.joinTapped,
            ),
          choice(
            waitIdentifier,
            l10n.seguimosWait,
            waitDetail,
            cubit.waitTapped,
          ),
        ],
      },
    ];
  }

  static String _line(AppLocalizations l10n, NearbyRonda nearby) =>
      l10n.rondaLineOf(
        slotDayId: nearby.slotDayId,
        slotBandId: nearby.slotBandId,
        pretextId: nearby.pretextId,
      );
}
