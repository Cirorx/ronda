import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/safety_queue/cubit/safety_queue_cubit.dart';
import 'package:ronda/safety_queue/widgets/report_card.dart';
import 'package:ronda_ui/ronda_ui.dart';
import 'package:safety_repository/safety_repository.dart';

/// "Reportes": the admin's queue of what members told Ronda, opened from
/// the admin screen. Only the admin reads it; the server checks again.
class const SafetyQueuePage({super.key}) extends StatelessWidget {
  /// Under the admin screen, so the router lets a profile-less owner in.
  static const path = '/admin/reportes';

  /// The route's segment under `/admin`.
  static const segment = 'reportes';

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          SafetyQueueCubit(safetyRepository: context.read<SafetyRepository>())
            ..subscribe(),
      child: const SafetyQueueView(),
    );
  }
}

/// "Abiertos" and "Archivados", each report as a [ReportCard] (anyone
/// reported by two or more people on top), then "Separados" with
/// "Juntarlos de nuevo" and "Fuera de Ronda" with "Dejar entrar de nuevo".
class const SafetyQueueView({super.key}) extends StatelessWidget {
  /// Maestro's handle on the tabs.
  static const tabsIdentifier = 'reports_tabs';

  /// Prefix of "Juntarlos de nuevo"'s handles, each ending in the pair id.
  static const joinAgainIdentifier = 'reports_join_again';

  /// Prefix of "Dejar entrar de nuevo"'s handles, each ending in the uid.
  static const letBackInIdentifier = 'reports_let_back_in';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<SafetyQueueCubit>().state;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.safetyQueueTitle)),
      body: SafeArea(
        child: RondaSwap(
          layoutBuilder: RondaSwap.topStartLayout,
          child: switch (state.status) {
            SafetyQueueStatus.loading => LoadingStatus(
              l10n.safetyQueueLoading,
              key: const ValueKey(SafetyQueueStatus.loading),
            ),
            SafetyQueueStatus.forbidden => _Message(
              l10n.adminForbidden,
              key: const ValueKey(SafetyQueueStatus.forbidden),
            ),
            SafetyQueueStatus.failure => _Message(
              l10n.safetyQueueLoadError,
              key: const ValueKey(SafetyQueueStatus.failure),
              action: OutlinedButton(
                onPressed: context.read<SafetyQueueCubit>().subscribe,
                child: Text(l10n.adminRetry),
              ),
            ),
            SafetyQueueStatus.ready => _Queue(
              state,
              key: const ValueKey(SafetyQueueStatus.ready),
            ),
          },
        ),
      ),
    );
  }
}

class const _Message(final String message, {final Widget? action, super.key})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return Center(
      child: Padding(
        padding: EdgeInsetsDirectional.all(spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: spacing.md,
          children: [
            StatusLine(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            ?action,
          ],
        ),
      ),
    );
  }
}

class const _Queue(final SafetyQueueState state, {super.key})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final spacing = context.appSpacing;
    final cubit = context.read<SafetyQueueCubit>();
    final shown = state.shown;
    final localizations = MaterialLocalizations.of(context);
    String date(DateTime at) => localizations.formatShortMonthDay(at.toLocal());

    Widget heading(String text) => Semantics(
      header: true,
      child: Text(text, style: theme.textTheme.titleMedium),
    );

    Widget undo(String identifier, String id, String label, VoidCallback on) =>
        MergeSemantics(
          child: Semantics(
            identifier: '$identifier.$id',
            child: OutlinedButton(
              onPressed: state.busy == null ? on : null,
              child: Text(label, textAlign: TextAlign.center),
            ),
          ),
        );

    String name(String value) => value.isEmpty ? l10n.safetySomeone : value;

    return ReadableColumn(
      child: ListView(
        padding: EdgeInsetsDirectional.symmetric(
          horizontal: spacing.lg,
          vertical: spacing.md,
        ),
        children: [
          if (state.actionFailed) ...[
            NoteBanner(
              variant: NoteBannerVariant.warning,
              message: l10n.safetyActionFailed,
            ),
            SizedBox(height: spacing.md),
          ],
          Semantics(
            identifier: SafetyQueueView.tabsIdentifier,
            child: SegmentedButton<SafetyQueueTab>(
              segments: [
                ButtonSegment(
                  value: SafetyQueueTab.open,
                  label: Text('${l10n.safetyOpenTab} (${state.openCount})'),
                ),
                ButtonSegment(
                  value: SafetyQueueTab.archived,
                  label: Text(l10n.safetyArchivedTab),
                ),
              ],
              selected: {state.tab},
              showSelectedIcon: false,
              onSelectionChanged: (tabs) => cubit.tabChanged(tabs.single),
            ),
          ),
          SizedBox(height: spacing.md),
          if (shown.isEmpty)
            Text(
              state.tab == SafetyQueueTab.open
                  ? l10n.safetyNoneOpen
                  : l10n.safetyNoneArchived,
              style: theme.textTheme.bodyLarge,
            ),
          for (final report in shown) ...[
            ReportCard(report: report),
            SizedBox(height: spacing.sm),
          ],
          if (state.queue.separated.isNotEmpty) ...[
            SizedBox(height: spacing.lg),
            heading(l10n.safetySeparatedTitle),
            for (final pair in state.queue.separated) ...[
              SizedBox(height: spacing.xs),
              Text(
                l10n.safetyPair(name(pair.nameA), name(pair.nameB)),
                style: theme.textTheme.bodyLarge,
              ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: undo(
                  SafetyQueueView.joinAgainIdentifier,
                  pair.id,
                  l10n.safetyJoinAgain,
                  () => cubit.joinAgain(pair.id),
                ),
              ),
            ],
          ],
          if (state.queue.removed.isNotEmpty) ...[
            SizedBox(height: spacing.lg),
            heading(l10n.safetyRemovedTitle),
            for (final person in state.queue.removed) ...[
              SizedBox(height: spacing.xs),
              Text(
                l10n.safetyRemovedSince(
                  name(person.firstName),
                  date(person.at),
                ),
                style: theme.textTheme.bodyLarge,
              ),
              if (person.notice == RemovalNotice.pending)
                Text(
                  l10n.safetyNoticePending,
                  style: theme.textTheme.bodyMedium,
                ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: undo(
                  SafetyQueueView.letBackInIdentifier,
                  person.uid,
                  l10n.safetyLetBackIn,
                  () => cubit.letBackIn(person.uid),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
