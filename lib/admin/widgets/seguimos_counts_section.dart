import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ronda/admin/cubit/seguimos_counts_cubit.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/my_ronda/widgets/this_week_labels.dart';
import 'package:ronda_repository/ronda_repository.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// "¿Seguimos?" on the admin screen: per ronda, sí / no / sin contestar and
/// where it stands. Counts only. Reads the [SeguimosCountsCubit] above and
/// shows nothing until the counts are read (a refusal hides it too).
class const SeguimosCountsSection({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final spacing = context.appSpacing;
    final state = context.watch<SeguimosCountsCubit>().state;
    if (state.status != SeguimosCountsStatus.ready) {
      return const SizedBox.shrink();
    }

    String standing(SeguimosCounts ronda) => switch (ronda.status) {
      SeguimosStatus.open => l10n.adminSeguimosOpen,
      SeguimosStatus.season => l10n.adminSeguimosSeason(
        ronda.seasonEnd == null ? '' : l10n.shortDate(ronda.seasonEnd!),
      ),
      SeguimosStatus.didntFill => l10n.adminSeguimosDidntFill(
        ronda.join,
        ronda.wait,
      ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: spacing.xs,
      children: [
        Semantics(
          header: true,
          child: Text(l10n.adminSeguimosTitle, style: textTheme.titleMedium),
        ),
        Text(l10n.adminSeguimosBody, style: textTheme.bodyMedium),
        if (state.rondas.isEmpty)
          Text(l10n.adminSeguimosEmpty, style: textTheme.bodyMedium)
        else
          for (final ronda in state.rondas)
            Padding(
              padding: EdgeInsets.only(top: spacing.xs),
              child: MergeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // The server's own es-419 line: the admin reads Spanish.
                    Text(ronda.line, style: textTheme.titleSmall),
                    Text(
                      l10n.adminSeguimosCounts(
                        ronda.yes,
                        ronda.no,
                        ronda.unanswered,
                      ),
                      style: textTheme.bodyLarge,
                    ),
                    Text(standing(ronda), style: textTheme.bodyMedium),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}
