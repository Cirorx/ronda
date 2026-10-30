import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:organiser_repository/organiser_repository.dart';
import 'package:ronda/acta/cubit/acta_cubit.dart';
import 'package:ronda/app/app.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// "Lo que hizo el programa": a short, factual log of what the organiser
/// did this week for ronda [rondaId], read by its members
/// (`docs/PRODUCT.md` § Organiser agent).
class const ActaPage({
  /// The ronda whose acta this is.
  required final String rondaId,
  super.key,
}) extends StatelessWidget {
  /// The route, with the ronda's id in it.
  static const path = '/acta/:rondaId';

  /// Where ronda [rondaId]'s acta is.
  static String location(String rondaId) =>
      '/acta/${Uri.encodeComponent(rondaId)}';

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ActaCubit(
        uid: context.read<AppBloc>().state.user.id,
        rondaId: rondaId,
        organiserRepository: context.read<OrganiserRepository>(),
      )..subscribe(),
      child: const ActaView(),
    );
  }
}

/// The week's lines in the order they happened, each with its time, the
/// ones the host decided marked; the closing line; and [Algo estuvo mal].
class const ActaView({super.key}) extends StatelessWidget {
  /// Maestro's handle on [Algo estuvo mal].
  static const reportIdentifier = 'acta.report';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final spacing = context.appSpacing;
    final state = context.watch<ActaCubit>().state;
    final cubit = context.read<ActaCubit>();
    final localizations = MaterialLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.actaTitle)),
      body: SafeArea(
        child: switch (state.status) {
          ActaStatus.loading => const Center(
            child: CircularProgressIndicator(),
          ),
          ActaStatus.failure => Center(
            child: Padding(
              padding: EdgeInsetsDirectional.all(spacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                spacing: spacing.md,
                children: [
                  Text(
                    l10n.organiserLoadError,
                    textAlign: TextAlign.center,
                    style: textTheme.bodyLarge,
                  ),
                  OutlinedButton(
                    onPressed: cubit.subscribe,
                    child: Text(l10n.adminRetry),
                  ),
                ],
              ),
            ),
          ),
          ActaStatus.ready => ListView(
            padding: EdgeInsetsDirectional.all(spacing.md),
            children: [
              Text(l10n.actaIntro, style: textTheme.bodyLarge),
              SizedBox(height: spacing.md),
              if (state.acta.lines.isEmpty)
                Text(l10n.actaEmpty, style: textTheme.bodyLarge)
              else
                for (final line in state.acta.lines)
                  Padding(
                    padding: EdgeInsetsDirectional.only(bottom: spacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          [
                            localizations.formatShortMonthDay(
                              line.at.toLocal(),
                            ),
                            localizations.formatTimeOfDay(
                              TimeOfDay.fromDateTime(line.at.toLocal()),
                              alwaysUse24HourFormat: true,
                            ),
                            if (line.byHost) l10n.actaByHost,
                          ].join(' · '),
                          style: textTheme.labelMedium,
                        ),
                        // The server's es-419, like the pushes.
                        Text(line.summary, style: textTheme.bodyLarge),
                      ],
                    ),
                  ),
              Divider(height: spacing.xlg),
              Text(l10n.actaFooter, style: textTheme.bodyLarge),
              SizedBox(height: spacing.md),
              switch (state.report) {
                ActaReport.sent => Semantics(
                  liveRegion: true,
                  child: Text(l10n.actaReported, style: textTheme.bodyLarge),
                ),
                _ => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: spacing.sm,
                  children: [
                    if (state.report == ActaReport.failed)
                      NoteBanner(
                        variant: NoteBannerVariant.warning,
                        message: l10n.actaReportFailed,
                      ),
                    MergeSemantics(
                      child: Semantics(
                        identifier: reportIdentifier,
                        child: OutlinedButton(
                          onPressed:
                              state.acta.week == null ||
                                  state.report == ActaReport.sending
                              ? null
                              : cubit.reportTapped,
                          child: Text(l10n.actaReport),
                        ),
                      ),
                    ),
                  ],
                ),
              },
            ],
          ),
        },
      ),
    );
  }
}
