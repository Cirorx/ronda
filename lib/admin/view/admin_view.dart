import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ronda/admin/admin.dart';
import 'package:ronda/agent_trace/agent_trace.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/ronda_setup/ronda_setup.dart';
import 'package:ronda_repository/ronda_repository.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// The newest proposal: "Nadie recibe nada hasta que lo aprobás.", each
/// ronda with its checks, "Por qué no otra opción", and Aprobar; once
/// approved, "Aprobado. Les llega el martes a las 19." with Deshacer, the
/// one swapping for the other. Under it, spaced and titled rather than
/// ruled off, "El ¿Venís? de esta semana", "¿Seguimos?" and the pilot's
/// numbers. Aprobar, Deshacer and "Armar las rondas" are commits, felt as
/// one ([RondaHaptics]).
class const AdminView({super.key}) extends StatelessWidget {
  /// Maestro's handles on the screen's buttons.
  static const proposeIdentifier = 'admin_propose';
  static const approveIdentifier = 'admin_approve';
  static const undoIdentifier = 'admin_undo';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<ProposalsCubit>().state;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.adminTitle),
        actions: [
          if (state.status != ProposalsStatus.forbidden) const AgentTraceLink(),
          if (state.status != ProposalsStatus.forbidden) const RondaSetupLink(),
        ],
      ),
      body: SafeArea(
        child: switch (state.status) {
          ProposalsStatus.loading => LoadingStatus(l10n.adminLoading),
          ProposalsStatus.forbidden => _Message(l10n.adminForbidden),
          ProposalsStatus.failure => _Message(
            l10n.adminLoadError,
            action: OutlinedButton(
              onPressed: () => context.read<ProposalsCubit>().subscribe(),
              child: Text(l10n.adminRetry),
            ),
          ),
          ProposalsStatus.ready => _Proposal(state),
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

class const _Proposal(final ProposalsState state) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final spacing = context.appSpacing;
    final cubit = context.read<ProposalsCubit>();
    final proposal = state.proposal;
    final pending = proposal?.status == ProposalStatus.pending;

    final propose = _Button(
      identifier: AdminView.proposeIdentifier,
      label: state.action == ProposalsAction.proposing
          ? l10n.adminProposing
          : proposal == null
          ? l10n.adminPropose
          : l10n.adminProposeAgain,
      onPressed: RondaHaptics.onCommit(state.busy ? null : cubit.propose),
      filled: proposal == null,
    );

    return ListView(
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: spacing.lg,
        vertical: spacing.md,
      ),
      children: [
        if (state.actionFailed) ...[
          NoteBanner(
            variant: NoteBannerVariant.warning,
            message: l10n.adminActionError,
          ),
          SizedBox(height: spacing.md),
        ],
        if (proposal == null) ...[
          Text(l10n.adminEmpty, style: theme.textTheme.bodyLarge),
          SizedBox(height: spacing.lg),
          propose,
        ] else ...[
          RondaSwap(
            layoutBuilder: _topStart,
            child: pending
                ? NoteBanner(
                    key: const ValueKey(ProposalStatus.pending),
                    message: l10n.adminNobodyYet,
                  )
                : Column(
                    key: const ValueKey(ProposalStatus.approved),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: spacing.xs,
                    children: [
                      NoteBanner(
                        variant: NoteBannerVariant.keptOnPhone,
                        message: l10n.adminApproved,
                      ),
                      _Button(
                        identifier: AdminView.undoIdentifier,
                        label: l10n.adminUndo,
                        onPressed: RondaHaptics.onCommit(
                          state.busy ? null : cubit.undo,
                        ),
                        filled: false,
                      ),
                    ],
                  ),
          ),
          SizedBox(height: spacing.md),
          for (final ronda in proposal.rondas) ...[
            AdminProposalCard(ronda: ronda),
            SizedBox(height: spacing.sm),
          ],
          UnseatedList(proposal: proposal),
          if (proposal.rejectedReason case final reason?) ...[
            SizedBox(height: spacing.lg),
            Semantics(
              header: true,
              child: Text(
                l10n.adminWhyNotOther,
                style: theme.textTheme.titleMedium,
              ),
            ),
            SizedBox(height: spacing.xxs),
            // The solver's own es-419 sentence: the admin reads Spanish.
            Text(reason, style: theme.textTheme.bodyLarge),
          ],
          SizedBox(height: spacing.lg),
          if (pending && proposal.rondas.isNotEmpty) ...[
            _Button(
              identifier: AdminView.approveIdentifier,
              label: l10n.adminApprove,
              onPressed: RondaHaptics.onCommit(
                state.busy ? null : cubit.approve,
              ),
              filled: true,
            ),
            SizedBox(height: spacing.sm),
          ],
          if (pending) propose,
        ],
        // Sections are set apart by space and their own titles; the only
        // rules on this screen are the planilla's, between people.
        SizedBox(height: spacing.xlg),
        const RsvpPushSection(),
        SizedBox(height: spacing.xlg),
        const SeguimosCountsSection(),
        SizedBox(height: spacing.xlg),
        const PilotNumbersSection(),
      ],
    );
  }
}

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
