import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ronda/admin/cubit/add_to_ronda_cubit.dart';
import 'package:ronda/admin/widgets/admin_labels.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda_repository/ronda_repository.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// "Sumar a esta ronda": who is in the ronda now, and every sign-up who
/// could join it, with what doesn't match. Someone in another ronda moves,
/// after a confirmation in a sheet over this one. Sumar and Pasar are
/// commits, felt as one ([RondaHaptics]); what came of them is read out.
/// Opened from an approved ronda's card.
class const AddToRondaSheet({super.key}) extends StatelessWidget {
  /// Prefix of the move confirmation's actions' semantics identifiers.
  static const moveIdentifier = 'add_to_ronda.move';

  /// Opens the sheet for ronda [rondaId] with its own [AddToRondaCubit].
  static Future<void> show(
    BuildContext context, {
    required String rondaId,
    required RondaRepository rondaRepository,
  }) => showRondaSheet<void>(
    context: context,
    builder: (_) => BlocProvider(
      create: (_) {
        final cubit = AddToRondaCubit(
          rondaRepository: rondaRepository,
          rondaId: rondaId,
        );
        unawaited(cubit.load());
        return cubit;
      },
      child: const AddToRondaSheet(),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final spacing = context.appSpacing;
    final state = context.watch<AddToRondaCubit>().state;
    final candidates = state.candidates;

    return ListView(
      shrinkWrap: true,
      padding: EdgeInsetsDirectional.all(spacing.lg),
      children: [
        if (candidates != null)
          Semantics(
            header: true,
            child: Text(
              l10n.addToRondaTitle(candidates.line),
              style: textTheme.titleMedium,
            ),
          ),
        if (candidates == null)
          switch (state.status) {
            AddToRondaStatus.failure => Column(
              spacing: spacing.sm,
              children: [
                StatusLine(
                  l10n.addToRondaLoadError,
                  style: textTheme.bodyLarge,
                ),
                OutlinedButton(
                  onPressed: context.read<AddToRondaCubit>().load,
                  child: Text(l10n.adminRetry),
                ),
              ],
            ),
            _ => LoadingStatus(l10n.addToRondaLoading),
          }
        else ...[
          Text(
            [
              l10n.addToRondaTaken(candidates.taken, candidates.cap),
              ...candidates.members,
            ].join(' · '),
            style: textTheme.bodyMedium,
          ),
          if (_outcome(l10n, state) case (final variant, final message)) ...[
            SizedBox(height: spacing.sm),
            NoteBanner(variant: variant, message: message),
          ],
          if (candidates.full) ...[
            SizedBox(height: spacing.sm),
            NoteBanner(
              variant: NoteBannerVariant.warning,
              message: l10n.addToRondaFull,
            ),
          ],
          SizedBox(height: spacing.sm),
          if (candidates.people.isEmpty)
            Text(l10n.addToRondaEmpty, style: textTheme.bodyLarge)
          else
            for (final candidate in candidates.people)
              _CandidateTile(
                candidate: candidate,
                full: candidates.full,
                adding: state.adding,
              ),
        ],
      ],
    );
  }

  static (NoteBannerVariant, String)? _outcome(
    AppLocalizations l10n,
    AddToRondaState state,
  ) => switch (state.outcome) {
    AddOutcome.none => null,
    AddOutcome.added => (
      NoteBannerVariant.keptOnPhone,
      [
        l10n.addToRondaDone(state.lastName),
        for (final warning in state.warnings) '${_warning(l10n, warning)}.',
      ].join(' '),
    ),
    AddOutcome.full => (NoteBannerVariant.warning, l10n.addToRondaErrorFull),
    AddOutcome.alreadyIn => (
      NoteBannerVariant.warning,
      l10n.addToRondaErrorAlready(state.lastName),
    ),
    AddOutcome.failed => (NoteBannerVariant.warning, l10n.adminActionError),
  };

  static String _warning(AppLocalizations l10n, CandidateWarning warning) =>
      switch (warning) {
        CandidateWarning.slot => l10n.addToRondaWarnSlot,
        CandidateWarning.pretext => l10n.addToRondaWarnPretext,
        CandidateWarning.barrio => l10n.addToRondaWarnBarrio,
        CandidateWarning.seat => l10n.addToRondaWarnSeat,
      };
}

/// One sign-up: name, barrio and slots, the ronda they are in, what doesn't
/// match, and Sumar (or "Pasar a esta ronda", which asks first).
class const _CandidateTile({
  required final Candidate candidate,
  required final bool full,
  required final Candidate? adding,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final spacing = context.appSpacing;
    final moving = candidate.currentRondaLine;
    return Padding(
      padding: EdgeInsetsDirectional.only(bottom: spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PersonRow(
            initial: candidate.firstName.characters.firstOrNull ?? '?',
            name: candidate.firstName,
            detail: l10n.adminUnseatedDetail(
              l10n.barrioOf(candidate.barrioId),
              l10n.slotsOf(candidate.slotIds),
            ),
            showDivider: false,
          ),
          if (moving != null)
            Text(
              l10n.addToRondaInOther(moving),
              style: theme.textTheme.bodyMedium,
            ),
          for (final warning in candidate.warnings)
            Row(
              spacing: spacing.xs,
              children: [
                Icon(
                  Icons.warning_amber,
                  size: 18,
                  color: context.rondaPalette.ambar,
                ),
                Expanded(
                  child: Text(
                    AddToRondaSheet._warning(l10n, warning),
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          SizedBox(height: spacing.xxs),
          OutlinedButton(
            onPressed: full || adding != null
                ? null
                : moving == null
                ? RondaHaptics.onCommit(() => _add(context))
                : () => _move(context, moving),
            child: Text(
              adding == candidate
                  ? l10n.addToRondaAdding
                  : moving == null
                  ? l10n.addToRondaAdd
                  : l10n.addToRondaMove,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _add(BuildContext context) =>
      context.read<AddToRondaCubit>().add(candidate);

  /// "¿Pasar a Jorge?" in a sheet over this one: Pasar moves them, felt as
  /// a commit; Cancelar, the scrim or a drag down leave everything as it
  /// was.
  Future<void> _move(BuildContext context, String moving) async {
    final l10n = context.l10n;
    final cubit = context.read<AddToRondaCubit>();
    final confirmed = await StepSheet(
      identifier: AddToRondaSheet.moveIdentifier,
      title: l10n.addToRondaMoveTitle(candidate.firstName),
      body: l10n.addToRondaMoveBody(moving),
      primaryLabel: l10n.addToRondaMoveConfirm,
      onPrimary: RondaHaptics.onCommit(() => Navigator.of(context).pop(true))!,
      secondaryLabel: l10n.addToRondaCancel,
      onSecondary: () => Navigator.of(context).pop(false),
    ).show<bool>(context);
    if (confirmed ?? false) await cubit.add(candidate);
  }
}
