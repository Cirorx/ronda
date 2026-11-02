import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/safety_queue/cubit/safety_queue_cubit.dart';
import 'package:ronda/settings/widgets/report_tag_label.dart';
import 'package:ronda_ui/ronda_ui.dart';
import 'package:safety_repository/safety_repository.dart';

/// One report in the admin's queue: who told about whom, when and in which
/// ronda, the tags and the words, what was added later, and its marks
/// ("Nuevo", «retirado», how many people told about the same person,
/// separated, out of Ronda). Then "Separarlos", "Sacar de Ronda" (after a
/// confirmation) and "Archivar" or "Reabrir".
class const ReportCard({required final Report report, super.key})
    extends StatelessWidget {
  /// Prefix of the buttons' handles: `<prefix>.<action>.<reportId>`.
  static const identifier = 'reports_card';

  /// Prefix of the confirmation's handles (`reports_remove.primary`).
  static const removeSheetIdentifier = 'reports_remove';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final spacing = context.appSpacing;
    final state = context.watch<SafetyQueueCubit>().state;
    final cubit = context.read<SafetyQueueCubit>();
    final localizations = MaterialLocalizations.of(context);
    String date(DateTime at) => localizations.formatShortMonthDay(at.toLocal());

    final reporters = state.reportersOf(report.aboutUid);
    final separation = state.separationOf(report);
    final removed = !report.aboutOutsider && state.isRemoved(report.aboutUid);
    final idle = state.busy == null;

    Widget button(String action, String label, VoidCallback onPressed) =>
        MergeSemantics(
          child: Semantics(
            identifier: '$identifier.$action.${report.id}',
            child: OutlinedButton(
              onPressed: idle ? onPressed : null,
              child: Text(label, textAlign: TextAlign.center),
            ),
          ),
        );

    Widget mark(String text) => Chip(label: Text(text));

    final marks = [
      if (state.fresh.contains(report.id)) mark(l10n.safetyNew),
      if (report.withdrawn) mark(l10n.safetyWithdrawnMark),
    ];

    return Card(
      child: Padding(
        padding: EdgeInsets.all(spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: spacing.xs,
          children: [
            if (marks.isNotEmpty)
              Wrap(
                spacing: spacing.xs,
                runSpacing: spacing.xs,
                children: marks,
              ),
            Semantics(
              header: true,
              child: Text(
                report.aboutOutsider
                    ? l10n.safetyReportOutside(report.reporterName)
                    : l10n.safetyReportAbout(
                        report.reporterName,
                        report.aboutName,
                      ),
                style: theme.textTheme.titleMedium,
              ),
            ),
            Text(
              [
                l10n.safetyReportOn(date(report.createdAt)),
                if (report.rondaLine.isNotEmpty) report.rondaLine,
              ].join(' · '),
              style: theme.textTheme.bodyMedium,
            ),
            if (reporters >= SafetyQueueState.topReporters)
              NoteBanner(
                variant: NoteBannerVariant.warning,
                message: l10n.safetyReporters(reporters, report.aboutName),
              ),
            if (report.tags.isNotEmpty)
              Text(
                [for (final tag in report.tags) reportTagLabel(l10n, tag)]
                    .join(' · '),
                style: theme.textTheme.bodyLarge,
              ),
            if (report.text.isNotEmpty)
              Text(report.text, style: theme.textTheme.bodyLarge),
            for (final addition in report.additions) ...[
              Text(
                l10n.safetyAddedOn(date(addition.at)),
                style: theme.textTheme.labelLarge,
              ),
              Text(addition.text, style: theme.textTheme.bodyLarge),
            ],
            if (separation != null)
              Text(
                separation.togetherLine == null
                    ? l10n.safetySeparated
                    : l10n.safetyStillTogether(separation.togetherLine!),
                style: theme.textTheme.bodyMedium,
              ),
            if (removed)
              Text(l10n.safetyRemovedMark, style: theme.textTheme.bodyMedium),
            SizedBox(height: spacing.xxs),
            Wrap(
              spacing: spacing.xs,
              runSpacing: spacing.xs,
              children: [
                if (!report.aboutOutsider && separation == null)
                  button(
                    'separate',
                    l10n.safetySeparate,
                    () => cubit.separate(report.id),
                  ),
                if (!report.aboutOutsider && !removed)
                  button(
                    'remove',
                    l10n.safetyRemove,
                    () => _confirmRemove(context),
                  ),
                if (report.archived)
                  button(
                    'reopen',
                    l10n.safetyReopen,
                    () => cubit.reopen(report.id),
                  )
                else
                  button(
                    'archive',
                    l10n.safetyArchive,
                    () => cubit.archive(report.id),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// "¿Sacás a Beto de Ronda?": "Sacar" or "Mejor no".
  Future<void> _confirmRemove(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<SafetyQueueCubit>();
    final navigator = Navigator.of(context);
    return StepSheet(
      identifier: removeSheetIdentifier,
      title: l10n.safetyRemoveTitle(report.aboutName),
      body: l10n.safetyRemoveBody,
      primaryLabel: l10n.safetyRemoveConfirm,
      onPrimary: () {
        navigator.pop();
        unawaited(RondaHaptics.commit());
        unawaited(cubit.remove(report.id));
      },
      secondaryLabel: l10n.safetyCancel,
      onSecondary: navigator.pop,
    ).show<void>(context);
  }
}
