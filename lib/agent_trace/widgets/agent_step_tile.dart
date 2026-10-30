import 'package:organiser_repository/organiser_repository.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// One step of a run in the trace: a model answer, a tool call with its
/// reason and result, a message marked "Salió" or "Frenado" with the
/// gate's reason, the host's pick, a note, or why the run stopped. The
/// words are the server's es-419 (the admin reads Spanish).
class const AgentStepTile(final AgentStep step, {super.key})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final spacing = context.appSpacing;
    final when = formatClock(context, step.at);

    final (String title, List<Widget> body) = switch (step.kind) {
      AgentStepKind.model => (
        l10n.traceModelStep(
          step.model,
          (step.latency.inMilliseconds / 1000).toStringAsFixed(1),
        ),
        [
          if (step.tool.isNotEmpty) Text(l10n.traceCalls(step.tool)),
          if (step.summary.isNotEmpty) Text(step.summary),
        ],
      ),
      AgentStepKind.tool => (
        step.tool,
        [
          if (step.reason.isNotEmpty) Text(l10n.traceReason(step.reason)),
          if (step.arguments.isNotEmpty)
            Text(step.arguments, style: textTheme.bodySmall),
          Text(step.summary),
          if (step.refused)
            NoteBanner(
              variant: NoteBannerVariant.warning,
              message: l10n.traceRefused,
            ),
        ],
      ),
      AgentStepKind.message => (
        step.toHost
            ? l10n.traceToHost(step.toName)
            : l10n.traceToMember(step.toName),
        [Text('«${step.text}»'), _Outcome(step)],
      ),
      AgentStepKind.stop => (l10n.traceStopped(step.summary), <Widget>[]),
      AgentStepKind.host ||
      AgentStepKind.note ||
      AgentStepKind.other => (step.summary, <Widget>[]),
    };

    return Card(
      child: Padding(
        padding: EdgeInsets.all(spacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: spacing.xxs,
          children: [
            Text('${step.n} · $when', style: textTheme.labelMedium),
            Text(title, style: textTheme.titleSmall),
            DefaultTextStyle.merge(
              style: textTheme.bodyMedium,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: spacing.xxs,
                children: body,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class const _Outcome(final AgentStep step) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return switch (step.outcome) {
      MessageOutcome.sent => NoteBanner(
        variant: NoteBannerVariant.keptOnPhone,
        message: l10n.traceSent,
      ),
      MessageOutcome.held => NoteBanner(
        variant: NoteBannerVariant.warning,
        message: switch (step.releaseAt) {
          final at? => l10n.traceHeldUntil(
            step.heldBecause,
            MaterialLocalizations.of(context).formatMediumDate(at),
            formatClock(context, at),
          ),
          null => l10n.traceHeld(step.heldBecause),
        },
      ),
      MessageOutcome.unreachable => NoteBanner(message: l10n.traceUnreachable),
      MessageOutcome.skipped => NoteBanner(message: l10n.traceSkipped),
      MessageOutcome.none => const SizedBox.shrink(),
    };
  }
}

/// [at] as `18:04`, in this device's time.
String formatClock(BuildContext context, DateTime at) =>
    MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(at.toLocal()),
      alwaysUse24HourFormat: true,
    );
