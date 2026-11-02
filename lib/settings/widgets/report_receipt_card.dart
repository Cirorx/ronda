import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/settings/cubit/report_cubit.dart';
import 'package:ronda/settings/models/report_text.dart';
import 'package:ronda_ui/ronda_ui.dart';
import 'package:safety_repository/safety_repository.dart';

/// One open report of the person's own: "Lo recibimos. Lo lee una
/// persona.", when they sent it, and "Agregar algo" and "Retirar". It
/// never says what the admin did with it.
class const ReportReceiptCard({required final ReportReceipt receipt, super.key})
    extends StatelessWidget {
  /// Prefix of "Agregar algo"'s handles, each ending in the report's id.
  static const addIdentifier = 'report.add';

  /// Prefix of "Retirar"'s handles, each ending in the report's id.
  static const withdrawIdentifier = 'report.withdraw';

  /// Prefix of the sheets' handles (`report.addSheet.primary`).
  static const addSheetIdentifier = 'report.addSheet';
  static const withdrawSheetIdentifier = 'report.withdrawSheet';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final spacing = context.appSpacing;
    final state = context.watch<ReportCubit>().state;
    final mine = state.receiptId == receipt.id;
    final action = mine ? state.receiptAction : null;
    final busy =
        action == ReceiptAction.adding || action == ReceiptAction.withdrawing;
    final date = MaterialLocalizations.of(context)
        .formatShortMonthDay(receipt.createdAt.toLocal());

    Widget button(String identifier, String label, VoidCallback onPressed) =>
        MergeSemantics(
          child: Semantics(
            identifier: '$identifier.${receipt.id}',
            child: OutlinedButton(
              onPressed: busy ? null : onPressed,
              child: Text(label, textAlign: TextAlign.center),
            ),
          ),
        );

    return Card(
      child: Padding(
        padding: EdgeInsets.all(spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: spacing.xs,
          children: [
            Text(l10n.reportReceived, style: textTheme.titleMedium),
            Text(l10n.reportReceivedOn(date), style: textTheme.bodyMedium),
            if (action == ReceiptAction.added)
              StatusLine(l10n.reportAdded, style: textTheme.bodyMedium),
            if (action == ReceiptAction.failed)
              StatusLine(l10n.reportActionFailed, style: textTheme.bodyMedium),
            Wrap(
              spacing: spacing.xs,
              runSpacing: spacing.xs,
              children: [
                button(addIdentifier, l10n.reportAdd, () => _add(context)),
                button(
                  withdrawIdentifier,
                  l10n.reportWithdraw,
                  () => _withdraw(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// "¿Qué querés agregar?": a field and "Agregar", which sends what the
  /// cubit holds and closes the sheet.
  Future<void> _add(BuildContext context) {
    final cubit = context.read<ReportCubit>();
    final navigator = Navigator.of(context);
    final l10n = context.l10n;
    return showRondaSheet<void>(
      context: context,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: BlocBuilder<ReportCubit, ReportState>(
          builder: (context, state) => StepSheet(
            identifier: addSheetIdentifier,
            title: l10n.reportAddTitle,
            body: l10n.reportBody,
            primaryLabel: l10n.reportAddSend,
            onPrimary: () {
              if (!state.canAdd) return;
              navigator.pop();
              unawaited(cubit.addedTo(receipt.id));
            },
            child: TextField(
              autofocus: true,
              onChanged: cubit.additionChanged,
              minLines: 2,
              maxLines: 6,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l10n.reportTextLabel,
                errorText:
                    state.addition.error == ReportTextValidationError.tooLong
                    ? l10n.reportTextTooLong(ReportText.maxLength)
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// "¿Retirás lo que contaste?": "Retirar" or "Mejor no".
  Future<void> _withdraw(BuildContext context) {
    final cubit = context.read<ReportCubit>();
    final navigator = Navigator.of(context);
    final l10n = context.l10n;
    return StepSheet(
      identifier: withdrawSheetIdentifier,
      title: l10n.reportWithdrawTitle,
      body: l10n.reportWithdrawBody,
      primaryLabel: l10n.reportWithdraw,
      onPrimary: () {
        navigator.pop();
        unawaited(cubit.withdrawn(receipt.id));
      },
      secondaryLabel: l10n.reportKeep,
      onSecondary: navigator.pop,
    ).show<void>(context);
  }
}
