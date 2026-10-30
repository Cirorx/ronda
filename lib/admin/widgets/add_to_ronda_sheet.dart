import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ronda/admin/cubit/add_to_ronda_cubit.dart';
import 'package:ronda/admin/widgets/admin_labels.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda_repository/ronda_repository.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// "Sumar a esta ronda": who is in the ronda now, and every sign-up who
/// could join it, with what doesn't match. Someone in another ronda moves,
/// after a confirmation. Opened from an approved ronda's card.
class const AddToRondaSheet({super.key}) extends StatelessWidget {
  /// Opens the sheet for ronda [rondaId] with its own [AddToRondaCubit].
  static Future<void> show(
    BuildContext context, {
    required String rondaId,
    required RondaRepository rondaRepository,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
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
        if (candidates == null)
          switch (state.status) {
            AddToRondaStatus.failure => Column(
              spacing: spacing.sm,
              children: [
                Text(l10n.addToRondaLoadError, style: textTheme.bodyLarge),
                OutlinedButton(
                  onPressed: context.read<AddToRondaCubit>().load,
                  child: Text(l10n.adminRetry),
                ),
              ],
            ),
            _ => const Center(child: CircularProgressIndicator()),
          }
        else ...[
          Text(
            l10n.addToRondaTitle(candidates.line),
            style: textTheme.titleMedium,
          ),
          SizedBox(height: spacing.xxs),
          Text(
            [
              l10n.addToRondaTaken(candidates.taken, candidates.cap),
              ...candidates.members,
            ].join(' · '),
            style: textTheme.bodyMedium,
          ),
          if (_outcome(l10n, state) case (final variant, final message)) ...[
            SizedBox(height: spacing.sm),
            Semantics(
              liveRegion: true,
              child: NoteBanner(variant: variant, message: message),
            ),
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
/// match, and Sumar (or "Pasar a esta ronda").
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
                : () => _add(context, moving),
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

  Future<void> _add(BuildContext context, String? moving) async {
    final cubit = context.read<AddToRondaCubit>();
    if (moving != null) {
      final l10n = context.l10n;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.addToRondaMoveTitle(candidate.firstName)),
          content: Text(l10n.addToRondaMoveBody(moving)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.addToRondaCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.addToRondaMoveConfirm),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    await cubit.add(candidate);
  }
}
