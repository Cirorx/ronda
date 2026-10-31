import 'package:error_reporter/error_reporter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ronda/agent_trace/agent_trace.dart';
import 'package:ronda/error_log/cubit/error_log_cubit.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// "Errores de la app": what the web app reported in the last 30 days,
/// grouped by code and screen, for the admin. Opened from the admin screen.
class const ErrorLogPage({super.key}) extends StatelessWidget {
  /// Under the admin screen, so the router lets a profile-less owner in.
  static const path = '/admin/errores';

  /// The route's segment under `/admin`.
  static const segment = 'errores';

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          ErrorLogCubit(clientErrorLog: context.read<ClientErrorLog>())
            ..subscribe(),
      child: const ErrorLogView(),
    );
  }
}

/// The groups, each with how many times, when last and on which platforms;
/// a tapped group swaps in its reports ([RondaSwap]), and back (the button
/// or the system's) swaps the groups back.
class const ErrorLogView({super.key}) extends StatelessWidget {
  /// Prefix of the groups' semantics identifiers, each ending in its index.
  static const groupIdentifier = 'errors_group';

  /// Maestro's handle on "Todos los errores".
  static const backIdentifier = 'errors_back';

  /// The most reports a group lists.
  static const shownPerGroup = 20;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<ErrorLogCubit>().state;
    final group = state.group;
    return PopScope(
      canPop: group == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.read<ErrorLogCubit>().groupClosed();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.errorLogTitle)),
        body: SafeArea(
          child: RondaSwap(
            layoutBuilder: RondaSwap.topStartLayout,
            child: switch (state.status) {
              ErrorLogStatus.loading => LoadingStatus(
                l10n.errorLogLoading,
                key: const ValueKey(ErrorLogStatus.loading),
              ),
              ErrorLogStatus.forbidden => _Message(
                l10n.adminForbidden,
                key: const ValueKey(ErrorLogStatus.forbidden),
              ),
              ErrorLogStatus.failure => _Message(
                l10n.errorLogLoadError,
                key: const ValueKey(ErrorLogStatus.failure),
                action: OutlinedButton(
                  onPressed: context.read<ErrorLogCubit>().subscribe,
                  child: Text(l10n.adminRetry),
                ),
              ),
              ErrorLogStatus.ready when group != null => _Group(
                group,
                key: ValueKey(group.key),
              ),
              ErrorLogStatus.ready => _Groups(
                state.groups,
                key: const ValueKey(ErrorLogStatus.ready),
              ),
            },
          ),
        ),
      ),
    );
  }
}

/// A whole-screen line ([StatusLine]): why there is nothing, or what
/// failed, with what to do about it.
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

class const _Groups(final List<ErrorGroup> groups, {super.key})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final spacing = context.appSpacing;
    return ListView(
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: spacing.lg,
        vertical: spacing.md,
      ),
      children: [
        Text(l10n.errorLogBody, style: textTheme.bodyLarge),
        SizedBox(height: spacing.md),
        if (groups.isEmpty)
          StatusLine(l10n.errorLogEmpty, style: textTheme.bodyLarge)
        else
          for (final (index, group) in groups.indexed) ...[
            MergeSemantics(
              child: Semantics(
                identifier: '${ErrorLogView.groupIdentifier}.$index',
                child: Card(
                  margin: EdgeInsetsDirectional.zero,
                  child: ListTile(
                    onTap: () =>
                        context.read<ErrorLogCubit>().groupOpened(group.key),
                    title: Text(group.code, style: textTheme.titleMedium),
                    subtitle: Text(
                      [
                        _screen(l10n, group.screen),
                        l10n.errorLogCount(group.count),
                        l10n.errorLogLastSeen(_when(context, group.latest.at)),
                        group.platforms.join(', '),
                        if (group.fatal) l10n.errorLogFatal,
                      ].join(' · '),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                ),
              ),
            ),
            SizedBox(height: spacing.sm),
          ],
      ],
    );
  }
}

/// One group's newest reports: when, where it ran, the step, the scrubbed
/// message and stack.
class const _Group(final ErrorGroup group, {super.key})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final spacing = context.appSpacing;
    final shown = group.errors.take(ErrorLogView.shownPerGroup).toList();
    return ListView(
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: spacing.lg,
        vertical: spacing.md,
      ),
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: MergeSemantics(
            child: Semantics(
              identifier: ErrorLogView.backIdentifier,
              child: OutlinedButton.icon(
                onPressed: context.read<ErrorLogCubit>().groupClosed,
                icon: const Icon(Icons.arrow_back),
                label: Text(l10n.errorLogBack),
              ),
            ),
          ),
        ),
        SizedBox(height: spacing.md),
        Semantics(
          header: true,
          child: Text(group.code, style: textTheme.titleLarge),
        ),
        Text(
          [
            _screen(l10n, group.screen),
            l10n.errorLogCount(group.count),
          ].join(' · '),
          style: textTheme.bodyLarge,
        ),
        Text(l10n.errorLogShown(shown.length), style: textTheme.bodyMedium),
        for (final error in shown) ...[
          SizedBox(height: spacing.lg),
          Text(
            [
              _when(context, error.at),
              error.platform,
              '${error.appVersion} (${error.build})',
              error.flavor,
              if (error.fatal) l10n.errorLogFatal,
            ].join(' · '),
            style: textTheme.titleSmall,
          ),
          if (error.step.isNotEmpty)
            Text(l10n.errorLogStep(error.step), style: textTheme.bodyMedium),
          SelectableText(
            error.message.isEmpty ? l10n.errorLogNoMessage : error.message,
            style: textTheme.bodyMedium,
          ),
          if (error.stack.isNotEmpty) ...[
            SizedBox(height: spacing.xs),
            SelectableText(
              error.stack,
              style: textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ],
    );
  }
}

String _screen(AppLocalizations l10n, String screen) =>
    screen.isEmpty ? l10n.errorLogNoScreen : screen;

String _when(BuildContext context, DateTime at) =>
    '${MaterialLocalizations.of(context).formatShortMonthDay(at.toLocal())} '
    '${formatClock(context, at)}';
