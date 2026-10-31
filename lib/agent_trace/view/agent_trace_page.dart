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
/// rain check by hand, a commit felt as one ([RondaHaptics]). On a
/// desktop window the selected run's steps stand beside the list. Choosing
/// another run swaps its steps in ([RondaSwap]); steps landing in the same
/// run simply appear.
class const AgentTraceView({super.key}) extends StatelessWidget {
  /// Maestro's handles on the buttons.
  static const runIdentifier = 'trace_run';
  static const runAtNightIdentifier = 'trace_run_night';

  /// Prefix of the run picker's chips' semantics identifiers, each ending
  /// in its run's id.
  static const runsIdentifier = 'trace_runs';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<AgentTraceCubit>().state;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.traceTitle)),
      body: SafeArea(
        child: switch (state.status) {
          AgentTraceStatus.loading => LoadingStatus(l10n.traceLoading),
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

/// A whole-screen line ([StatusLine]): why there is nothing, or what
/// failed, with what to do about it. Reading shows a [LoadingStatus].
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

class const _Trace(final AgentTraceState state) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final spacing = context.appSpacing;
    final cubit = context.read<AgentTraceCubit>();
    final running = state.rainCheck == RainCheckStatus.running;
    final run = state.selectedRun;

    // On a desktop window the selected run's trace stands beside the list.
    final beside = context.windowSize == WindowSize.expanded;
    final padding = EdgeInsetsDirectional.symmetric(
      horizontal: spacing.lg,
      vertical: spacing.md,
    );
    final trace = RondaSwap(
      layoutBuilder: _topStart,
      child: run == null
          ? const SizedBox.shrink()
          : _Run(key: ValueKey(run.id), run: run, state: state),
    );
    final children = [
      Text(l10n.traceBody, style: textTheme.bodyLarge),
      SizedBox(height: spacing.md),
      Wrap(
        spacing: spacing.sm,
        runSpacing: spacing.sm,
        children: [
          _Button(
            identifier: AgentTraceView.runIdentifier,
            label: running ? l10n.traceRunning : l10n.traceRun,
            onPressed: RondaHaptics.onCommit(
              running ? null : cubit.rainCheckTapped,
            ),
            filled: true,
          ),
          _Button(
            identifier: AgentTraceView.runAtNightIdentifier,
            label: l10n.traceRunAtNight,
            onPressed: RondaHaptics.onCommit(
              running ? null : () => cubit.rainCheckTapped(atNight: true),
            ),
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
          container: true,
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
      // Set apart by space and a title rather than a rule.
      SizedBox(height: spacing.xlg),
      Semantics(
        header: true,
        child: Text(l10n.traceRunsTitle, style: textTheme.titleMedium),
      ),
      SizedBox(height: spacing.xs),
      if (state.runs.isEmpty)
        Text(l10n.traceEmpty, style: textTheme.bodyLarge)
      else ...[
        ChipPicker(
          identifier: AgentTraceView.runsIdentifier,
          multiSelect: false,
          options: [
            for (final each in state.runs)
              ChipPickerOption(
                value: each.id,
                label: [
                  l10n.traceRunLabel(each.week, _when(context, each.startedAt)),
                  _status(l10n, each.status),
                ].join(' · '),
              ),
          ],
          selected: {?state.selectedRunId},
          onChanged: (chosen) => cubit.runTapped(chosen.single),
        ),
        if (!beside) ...[SizedBox(height: spacing.md), trace],
      ],
    ];

    return switch (context.windowSize) {
      WindowSize.compact => ListView(padding: padding, children: children),
      WindowSize.medium => ReadableColumn(
        child: ListView(padding: padding, children: children),
      ),
      WindowSize.expanded => PaperColumns(
        mainWidth: runsWidth,
        sideWidth: WindowSize.readableWidth,
        main: ListView(padding: padding, children: children),
        side: ListView(
          padding: EdgeInsetsDirectional.symmetric(vertical: spacing.md),
          children: [trace],
        ),
      ),
    };
  }

  /// The run list's width beside the trace on a desktop window.
  static const double runsWidth = 440;

  static String _when(BuildContext context, DateTime at) =>
      '${MaterialLocalizations.of(context).formatShortMonthDay(at.toLocal())} '
      '${formatClock(context, at)}';
}

/// The selected run: its ronda, status and model, the flags, its last words
/// and its steps, as they land.
class const _Run({
  required final AgentRun run,
  required final AgentTraceState state,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final spacing = context.appSpacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
    );
  }
}

/// "corriendo", "terminó"…: a run's status in words.
String _status(AppLocalizations l10n, AgentRunStatus status) =>
    switch (status) {
      AgentRunStatus.running => l10n.traceStatusRunning,
      AgentRunStatus.done => l10n.traceStatusDone,
      AgentRunStatus.capped => l10n.traceStatusCapped,
      AgentRunStatus.stopped => l10n.traceStatusStopped,
      AgentRunStatus.failed => l10n.traceStatusFailed,
      AgentRunStatus.other => l10n.traceStatusOther,
    };

/// Lays a [RondaSwap]'s outgoing and incoming states over each other from
/// the top start, full width, so the swap stays in place in a list.
Widget _topStart(Widget? current, List<Widget> previous) =>
    Stack(fit: StackFit.passthrough, children: [...previous, ?current]);

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
