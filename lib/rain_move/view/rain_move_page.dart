import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:organiser_repository/organiser_repository.dart';
import 'package:ronda/app/widgets/feedback.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/rain_move/cubit/rain_move_cubit.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// "El jueves puede llover": the host's screen for ronda [rondaId]'s rain
/// proposal of [week], opened from the push (`docs/PRODUCT.md` § Organiser
/// agent). The rules let only that proposal's host read it.
class const RainMovePage({
  /// The ronda.
  required final String rondaId,

  /// The meeting's ISO week (`2026-W45`).
  required final String week,
  super.key,
}) extends StatelessWidget {
  /// The route; the push's link opens it.
  static const path = '/lluvia/:rondaId/:week';

  /// Where ronda [rondaId]'s proposal for [week] is.
  static String location(String rondaId, String week) =>
      '/lluvia/${Uri.encodeComponent(rondaId)}/${Uri.encodeComponent(week)}';

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => RainMoveCubit(
        rondaId: rondaId,
        week: week,
        organiserRepository: context.read<OrganiserRepository>(),
      )..subscribe(),
      child: const RainMoveView(),
    );
  }
}

/// The forecast, the options, the exact message of the one tapped, and
/// «Mandarlo»; once decided, what was picked and how many it reached.
///
/// The tapped option fills in and its message slides in on a [RondaSwap];
/// «Mandarlo» is a commit, felt on the tap, with a progress ring on it
/// while it goes.
class const RainMoveView({super.key}) extends StatelessWidget {
  /// Maestro's handle on an option's button.
  static String optionIdentifier(MoveChoice choice) => 'rain.${choice.name}';

  /// Maestro's handle on «Mandarlo».
  static const sendIdentifier = 'rain.send';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<RainMoveCubit>().state;
    final move = state.move;
    return Scaffold(
      appBar: AppBar(title: Text(move?.title ?? l10n.rainMoveLoadingTitle)),
      body: SafeArea(
        child: RondaSwap(
          layoutBuilder: topStartSwapLayout,
          child: KeyedSubtree(
            key: ValueKey(state.status),
            child: switch ((state.status, move)) {
              (RainMoveViewStatus.ready, final move?) => _Move(state, move),
              (RainMoveViewStatus.loading, _) => LoadingStatus(
                l10n.rainMoveLoading,
              ),
              (RainMoveViewStatus.forbidden, _) => _Message(l10n.rainMoveNone),
              (RainMoveViewStatus.failure, _) => _Message(
                l10n.organiserLoadError,
                action: OutlinedButton(
                  onPressed: context.read<RainMoveCubit>().subscribe,
                  child: Text(l10n.adminRetry),
                ),
              ),
              _ => _Message(l10n.rainMoveNone),
            },
          ),
        ),
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

class const _Move(final RainMoveState state, final RainMove move)
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final spacing = context.appSpacing;
    final cubit = context.read<RainMoveCubit>();
    final selected = state.selectedOption;
    final sending = state.sending == RainMoveSending.sending;
    final late = state.sending == RainMoveSending.late;
    final phase = switch (move.status) {
      RainMoveStatus.decided => _Phase.decided,
      RainMoveStatus.expired => _Phase.expired,
      _ when late => _Phase.expired,
      _ => _Phase.open,
    };

    return ListView(
      padding: EdgeInsetsDirectional.all(spacing.md),
      children: [
        if (move.standIn) ...[
          NoteBanner(message: l10n.rainMoveStandIn),
          SizedBox(height: spacing.md),
        ],
        // The server's es-419: "Jueves 16:00 · lluvia 80%. …".
        Text(move.forecast, style: textTheme.titleMedium),
        SizedBox(height: spacing.md),
        RondaSwap(
          layoutBuilder: topStartSwapLayout,
          child: Column(
            key: ValueKey(phase),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: switch (phase) {
              _Phase.decided => [
                if (move.picked case final picked?)
                  Text(
                    l10n.rainMovePicked(picked.label),
                    style: textTheme.bodyLarge,
                  ),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    l10n.rainMoveSent(move.sent ?? 0),
                    style: textTheme.bodyLarge,
                  ),
                ),
              ],
              _Phase.expired => [
                NoteBanner(
                  variant: NoteBannerVariant.warning,
                  message: l10n.rainMoveExpired,
                ),
              ],
              _Phase.open => [
                Text(
                  l10n.rainMoveIntro(move.recipients),
                  style: textTheme.bodyLarge,
                ),
                SizedBox(height: spacing.md),
                for (final option in move.options) ...[
                  _Option(
                    option: option,
                    selected: option.choice == state.selected,
                    onPressed: () => cubit.optionTapped(option.choice),
                  ),
                  SizedBox(height: spacing.xs),
                ],
                RondaSwap(
                  layoutBuilder: topStartSwapLayout,
                  child: selected == null
                      ? const SizedBox.shrink(key: ValueKey('none'))
                      : Column(
                          key: ValueKey(selected.choice),
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(height: spacing.sm),
                            Text(
                              l10n.rainMoveTheyGet,
                              style: textTheme.titleSmall,
                            ),
                            SizedBox(height: spacing.xs),
                            Card(
                              child: Padding(
                                padding: EdgeInsetsDirectional.all(spacing.md),
                                child: Text(
                                  selected.message,
                                  style: textTheme.bodyLarge,
                                ),
                              ),
                            ),
                            SizedBox(height: spacing.xs),
                            Text(
                              l10n.rainMoveFirstMessage,
                              style: textTheme.bodySmall,
                            ),
                          ],
                        ),
                ),
                if (selected != null) ...[
                  SizedBox(height: spacing.md),
                  if (state.sending == RainMoveSending.failed) ...[
                    NoteBanner(
                      variant: NoteBannerVariant.warning,
                      message: l10n.rainMoveError,
                    ),
                    SizedBox(height: spacing.sm),
                  ],
                  MergeSemantics(
                    child: Semantics(
                      identifier: RainMoveView.sendIdentifier,
                      liveRegion: sending,
                      child: IgnorePointer(
                        ignoring: sending,
                        child: FilledButton(
                          onPressed: sending
                              ? () {}
                              : RondaHaptics.onCommit(cubit.sendTapped),
                          child: BusyLabel(
                            sending ? l10n.rainMoveSending : l10n.rainMoveSend,
                            busy: sending,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            },
          ),
        ),
      ],
    );
  }
}

/// Where the proposal stands on the host's screen.
enum _Phase { open, decided, expired }

/// One option: filled once tapped, swapped in on a [RondaSwap].
class const _Option({
  required final RainOption option,
  required final bool selected,
  required final VoidCallback onPressed,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final label = Text(option.label);
    return MergeSemantics(
      child: Semantics(
        identifier: RainMoveView.optionIdentifier(option.choice),
        selected: selected,
        child: RondaSwap(
          layoutBuilder: topStartSwapLayout,
          child: selected
              ? FilledButton(
                  key: const ValueKey(true),
                  onPressed: onPressed,
                  child: label,
                )
              : OutlinedButton(
                  key: const ValueKey(false),
                  onPressed: onPressed,
                  child: label,
                ),
        ),
      ),
    );
  }
}
