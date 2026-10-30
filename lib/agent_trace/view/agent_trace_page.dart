import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:organiser_repository/organiser_repository.dart';
import 'package:ronda/agent_trace/cubit/agent_trace_cubit.dart';
import 'package:ronda/agent_trace/widgets/agent_step_tile.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// "Lo que mandó el programa": the organiser agent's trace, live, for the
/// admin (`docs/PRODUCT.md` § Screens). Opened from the admin screen.
class const AgentTracePage({super.key}) extends StatelessWidget {
  /// Under the admin screen, so the router lets a profile-less owner in.
  static const path = '/admin/programa';

  /// The route's segment under `/admin`.
  static const segment = 'programa';

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AgentTraceCubit(
        organiserRepository: context.read<OrganiserRepository>(),
      )..subscribe(),
      child: const AgentTraceView(),
    );
  }
}

/// The runs, newest first, the selected run's steps as they land, and the
/// rain check by hand.
class const AgentTraceView({super.key}) extends StatelessWidget {
  /// Maestro's handles on the buttons.
  static const runIdentifier = 'trace_run';
  static const runAtNightIdentifier = 'trace_run_night';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<AgentTraceCubit>().state;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.traceTitle)),
      body: SafeArea(
        child: switch (state.status) {
          AgentTraceStatus.loading => const Center(
            child: CircularProgressIndicator(),
          ),
          AgentTraceStatus.forbidden => _Message(l10n.adminForbidden),
          AgentTraceStatus.failure => _Message(
            l10n.organiserLoadError,
            action: OutlinedButton(
              onPressed: context.read<AgentTraceCubit>().subscribe,
              child: Text(l10n.adminRetry),
            ),
          ),
          AgentTraceStatus.ready => _Trace(state),
        },
      ),
    );
  }
}

class const _Message(final String message, {final Widget? action})
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
            Text(
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

class const _Trace(final AgentTraceState state) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final spacing = context.appSpacing;
    final cubit = context.read<AgentTraceCubit>();
    final running = state.rainCheck == RainCheckStatus.running;
    final run = state.selectedRun;

    return ListView(
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: spacing.lg,
        vertical: spacing.md,
      ),
      children: [
        Text(l10n.traceBody, style: textTheme.bodyLarge),
        SizedBox(height: spacing.md),
        Wrap(
          spacing: spacing.sm,
          runSpacing: spacing.sm,
          children: [
            _Button(
              identifier: AgentTraceView.runIdentifier,
              label: running ? l10n.traceRunning : l10n.traceRun,
              onPressed: running ? null : cubit.rainCheckTapped,
              filled: true,
            ),
            _Button(
              identifier: AgentTraceView.runAtNightIdentifier,
              label: l10n.traceRunAtNight,
              onPressed: running
                  ? null
                  : () => cubit.rainCheckTapped(atNight: true),
              filled: false,
            ),
          ],
        ),
        if (state.rainCheck == RainCheckStatus.failed) ...[
          SizedBox(height: spacing.sm),
          NoteBanner(
            variant: NoteBannerVariant.warning,
            message: l10n.adminActionError,
          ),
        ],
        if (state.result case final result?
            when state.rainCheck == RainCheckStatus.done) ...[
          SizedBox(height: spacing.sm),
          Semantics(
            liveRegion: true,
            child: Text(
              [
                l10n.traceRunResult(result.checked),
                if (result.failed > 0) l10n.traceRunFailed(result.failed),
              ].join(' '),
              style: textTheme.bodyMedium,
            ),
          ),
        ],
        Divider(height: spacing.xlg),
        if (state.runs.isEmpty)
          Text(l10n.traceEmpty, style: textTheme.bodyLarge)
        else ...[
          Wrap(
            spacing: spacing.xs,
            runSpacing: spacing.xs,
            children: [
              for (final each in state.runs)
                ChoiceChip(
                  label: Text(
                    [
                      l10n.traceRunLabel(
                        each.week,
                        _when(context, each.startedAt),
                      ),
                      _status(l10n, each.status),
                    ].join(' · '),
                  ),
                  selected: each.id == state.selectedRunId,
                  onSelected: (_) => cubit.runTapped(each.id),
                ),
            ],
          ),
          if (run != null) ...[
            SizedBox(height: spacing.md),
            Text(
              [
                run.rondaId,
                _status(l10n, run.status),
                if (run.model.isNotEmpty)
                  run.model
                else if (run.status == AgentRunStatus.done)
                  l10n.traceNoModel,
                if (run.forced) l10n.traceRunByHand,
              ].join(' · '),
              style: textTheme.titleMedium,
            ),
            Text(l10n.traceFlags(state.flagCount), style: textTheme.bodyMedium),
            if (run.note.isNotEmpty)
              Text(l10n.traceLastWords(run.note), style: textTheme.bodyMedium),
            SizedBox(height: spacing.sm),
            for (final step in state.steps) ...[
              AgentStepTile(step),
              SizedBox(height: spacing.xs),
            ],
          ],
        ],
      ],
    );
  }

  static String _when(BuildContext context, DateTime at) =>
      '${MaterialLocalizations.of(context).formatShortMonthDay(at.toLocal())} '
      '${formatClock(context, at)}';

  static String _status(AppLocalizations l10n, AgentRunStatus status) =>
      switch (status) {
        AgentRunStatus.running => l10n.traceStatusRunning,
        AgentRunStatus.done => l10n.traceStatusDone,
        AgentRunStatus.capped => l10n.traceStatusCapped,
        AgentRunStatus.stopped => l10n.traceStatusStopped,
        AgentRunStatus.failed => l10n.traceStatusFailed,
        AgentRunStatus.other => l10n.traceStatusOther,
      };
}

class const _Button({
  required final String identifier,
  required final String label,
  required final VoidCallback? onPressed,
  required final bool filled,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Semantics(
        identifier: identifier,
        child: filled
            ? FilledButton(onPressed: onPressed, child: Text(label))
            : OutlinedButton(onPressed: onPressed, child: Text(label)),
      ),
    );
  }
}
