import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ronda/admin/cubit/pilot_numbers_cubit.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/my_ronda/widgets/this_week_labels.dart';
import 'package:ronda_repository/ronda_repository.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// The [PilotNumbersCubit] for the admin page's providers, counting as soon
/// as the screen opens.
BlocProvider<PilotNumbersCubit> pilotNumbersProvider() => BlocProvider(
  create: (context) {
    final cubit = PilotNumbersCubit(
      rondaRepository: context.read<RondaRepository>(),
    );
    unawaited(cubit.load());
    return cubit;
  },
);

/// "Los números del piloto": sign-ups, seats, and per ronda its members,
/// each week's RSVP and attendance, came back and ¿seguimos?, each as "x de
/// y". Reads the [PilotNumbersCubit] above; hidden for anyone but the admin.
class const PilotNumbersSection({super.key}) extends StatelessWidget {
  /// Maestro's handle on "Contar de nuevo".
  static const refreshIdentifier = 'admin_pilot_refresh';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final spacing = context.appSpacing;
    final state = context.watch<PilotNumbersCubit>().state;
    if (state.status == PilotNumbersStatus.forbidden) {
      return const SizedBox.shrink();
    }
    final numbers = state.numbers;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: spacing.xs,
      children: [
        Text(l10n.pilotTitle, style: textTheme.titleMedium),
        Text(l10n.pilotBody, style: textTheme.bodyMedium),
        if (state.status == PilotNumbersStatus.failure)
          NoteBanner(
            variant: NoteBannerVariant.warning,
            message: l10n.pilotLoadError,
          ),
        if (numbers == null && state.status == PilotNumbersStatus.loading)
          const Center(child: CircularProgressIndicator()),
        if (numbers != null) ...[
          Text(
            l10n.pilotProfiles(numbers.profiles.count, numbers.profiles.of),
            style: textTheme.bodyLarge,
          ),
          Text(
            l10n.pilotSeated(numbers.seated.count, numbers.seated.of),
            style: textTheme.bodyLarge,
          ),
          Text(_cameBack(l10n, numbers.cameBack), style: textTheme.bodyLarge),
          if (numbers.rondas.isEmpty)
            Text(l10n.pilotEmpty, style: textTheme.bodyMedium)
          else
            for (final ronda in numbers.rondas) _Ronda(ronda: ronda),
        ],
        MergeSemantics(
          child: Semantics(
            identifier: refreshIdentifier,
            child: OutlinedButton(
              onPressed: state.status == PilotNumbersStatus.loading
                  ? null
                  : context.read<PilotNumbersCubit>().load,
              child: Text(l10n.pilotRefresh),
            ),
          ),
        ),
      ],
    );
  }

  static String _cameBack(AppLocalizations l10n, CountOf? cameBack) =>
      switch (cameBack) {
        null => l10n.pilotCameBackNone,
        CountOf(:final count, :final of) => l10n.pilotCameBack(count, of),
      };
}

/// One ronda: its line, members, each week, came back and ¿seguimos?.
class const _Ronda({required final PilotRonda ronda}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final spacing = context.appSpacing;
    return Padding(
      padding: EdgeInsetsDirectional.only(top: spacing.xs),
      child: MergeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The server's own es-419 line: the admin reads Spanish.
            Text(ronda.line, style: textTheme.titleSmall),
            Text(
              l10n.pilotMembers(ronda.members.count, ronda.members.of),
              style: textTheme.bodyMedium,
            ),
            for (final week in ronda.weeks) ...[
              Text(
                l10n.pilotWeekRsvp(
                  switch (week.date) {
                    final date? => l10n.shortDate(date),
                    null => week.week,
                  },
                  week.yes.count,
                  week.yes.of,
                  week.no,
                  week.unanswered,
                ),
                style: textTheme.bodyMedium,
              ),
              Text(switch (week.came) {
                CountOf(:final count, :final of) => l10n.pilotWeekCame(
                  count,
                  of,
                ),
                null => l10n.pilotWeekUnmarked,
              }, style: textTheme.bodyMedium),
            ],
            if (ronda.cameBack case CountOf(:final count, :final of))
              Text(l10n.pilotCameBack(count, of), style: textTheme.bodyMedium),
            if (ronda.seguimos case final seguimos?)
              Text(
                l10n.pilotSeguimos(
                  seguimos.yes.count,
                  seguimos.yes.of,
                  seguimos.no,
                  seguimos.unanswered,
                ),
                style: textTheme.bodyMedium,
              ),
          ],
        ),
      ),
    );
  }
}
