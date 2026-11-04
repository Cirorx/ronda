import 'package:contact_repository/contact_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ronda/app/app.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/settings/cubit/contact_cubit.dart';
import 'package:ronda/settings/cubit/report_cubit.dart';
import 'package:ronda/settings/models/report_text.dart';
import 'package:ronda/settings/widgets/helpline_block.dart';
import 'package:ronda/settings/widgets/report_receipt_card.dart';
import 'package:ronda/settings/widgets/report_tag_label.dart';
import 'package:ronda_ui/ronda_ui.dart';
import 'package:safety_repository/safety_repository.dart';

/// Ajustes → "Contar algo que pasó": the in-app report, the person's own
/// receipts and the helplines.
class const ReportPage({super.key}) extends StatelessWidget {
  /// The route's segment under `/ajustes`.
  static const segment = 'contar';
  static const path = '/ajustes/$segment';

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => ReportCubit(
            safetyRepository: context.read<SafetyRepository>(),
            uid: context.read<AppBloc>().state.user.id,
          )..load(),
        ),
        BlocProvider(
          create: (context) => ContactCubit(
            contactRepository: context.read<ContactRepository>(),
          ),
        ),
      ],
      child: const ReportView(),
    );
  }
}

/// "Contá qué pasó. Lo lee una persona, no un programa…", "Si estás en
/// peligro ahora, llamá al 911.", each open receipt ("Lo recibimos. Lo lee
/// una persona." with "Agregar algo" and "Retirar"), the form ("¿Qué
/// pasó?", "¿Con quién?", the words, "Mandar"), then the [HelplineBlock].
class const ReportView({super.key}) extends StatelessWidget {
  /// Maestro's handle on "Mandar".
  static const sendIdentifier = 'report.send';

  /// Maestro's handle on the words.
  static const textIdentifier = 'report.text';

  /// Prefix of the tags' handles, each ending in the tag's name.
  static const tagIdentifier = 'report.tag';

  /// Prefix of "¿Con quién?"'s handles, each ending in the uid, or
  /// `outside` for "Alguien de afuera".
  static const whoIdentifier = 'report.who';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final spacing = context.appSpacing;
    final state = context.watch<ReportCubit>().state;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsReportRow)),
      body: SafeArea(
        top: false,
        child: ReadableColumn(
          child: ListView(
            padding: EdgeInsets.all(spacing.md),
            children: [
              Text(l10n.reportBody, style: textTheme.bodyLarge),
              SizedBox(height: spacing.sm),
              NoteBanner(
                variant: NoteBannerVariant.warning,
                message: l10n.reportDangerNow,
              ),
              SizedBox(height: spacing.lg),
              for (final receipt in state.openReceipts) ...[
                ReportReceiptCard(receipt: receipt),
                SizedBox(height: spacing.sm),
              ],
              if (state.status == ReportStatus.loading)
                LoadingStatus.inline(l10n.reportLoading)
              else
                const _ReportForm(),
              SizedBox(height: spacing.xlg),
              const HelplineBlock(),
            ],
          ),
        ),
      ),
    );
  }
}

/// The form. The field shows what the cubit holds, and is emptied when the
/// report is saved; sending reads the cubit's state, never the field.
class _ReportForm extends StatefulWidget {
  const new();

  @override
  State<_ReportForm> createState() => _ReportFormState();
}

class _ReportFormState extends State<_ReportForm> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final spacing = context.appSpacing;
    final cubit = context.read<ReportCubit>();
    final state = context.watch<ReportCubit>().state;

    Widget heading(String text) => Semantics(
      header: true,
      child: Text(text, style: textTheme.titleMedium),
    );

    Widget who(String uid, String label) => MergeSemantics(
      child: Semantics(
        identifier:
            '${ReportView.whoIdentifier}.${uid.isEmpty ? 'outside' : uid}',
        child: ChoiceChip(
          label: Text(label),
          selected: state.aboutUid == uid,
          onSelected: (_) => cubit.aboutChosen(uid),
        ),
      ),
    );

    final sending = state.send == ReportSendStatus.sending;
    final note = switch (state.send) {
      ReportSendStatus.failed => l10n.reportSendFailed,
      ReportSendStatus.tooMany => l10n.reportTooMany,
      _ => null,
    };

    return BlocListener<ReportCubit, ReportState>(
      listenWhen: (previous, current) =>
          previous.send != current.send &&
          current.send == ReportSendStatus.sent,
      listener: (_, _) => _text.clear(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          heading(l10n.reportWhatTitle),
          SizedBox(height: spacing.xs),
          Wrap(
            spacing: spacing.xs,
            runSpacing: spacing.xs,
            children: [
              for (final tag in ReportTag.values)
                MergeSemantics(
                  child: Semantics(
                    identifier: '${ReportView.tagIdentifier}.${tag.name}',
                    child: FilterChip(
                      label: Text(reportTagLabel(l10n, tag)),
                      selected: state.tags.contains(tag),
                      onSelected: (_) => cubit.tagToggled(tag),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: spacing.lg),
          heading(l10n.reportWhoTitle),
          SizedBox(height: spacing.xs),
          Wrap(
            spacing: spacing.xs,
            runSpacing: spacing.xs,
            children: [
              for (final person in state.people)
                who(person.uid, person.firstName),
              who('', l10n.reportWhoOutside),
            ],
          ),
          SizedBox(height: spacing.lg),
          Semantics(
            identifier: ReportView.textIdentifier,
            child: TextField(
              controller: _text,
              onChanged: cubit.textChanged,
              minLines: 3,
              maxLines: 8,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l10n.reportTextLabel,
                alignLabelWithHint: true,
                errorText: state.text.error == ReportTextValidationError.tooLong
                    ? l10n.reportTextTooLong(ReportText.maxLength)
                    : null,
              ),
            ),
          ),
          SizedBox(height: spacing.md),
          if (!state.canSend && !sending) ...[
            Text(l10n.reportSendHint, style: textTheme.bodyMedium),
            SizedBox(height: spacing.xs),
          ],
          if (note != null) ...[
            StatusLine(note, style: textTheme.bodyMedium),
            SizedBox(height: spacing.xs),
          ],
          MergeSemantics(
            child: Semantics(
              identifier: ReportView.sendIdentifier,
              child: FilledButton(
                onPressed: state.canSend
                    ? RondaHaptics.onCommit(cubit.submitted)
                    : null,
                child: BusyLabel(
                  sending ? l10n.reportSending : l10n.reportSend,
                  busy: sending,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
