import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/push/cubit/push_cubit.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// The card that asks before the system does: "¿Te avisamos los martes?",
/// what Ronda will send and when, [Sí, avisame] (felt as it is tapped)
/// [Ahora no]. When the phone refused for good, how to turn them on swaps in
/// under the same title and is read out. Shows only while
/// [PushState.showsPrompt]; reads the [PushCubit] above it.
class const PushPrompt({super.key}) extends StatelessWidget {
  /// Maestro's handles on the card and its buttons.
  static const identifier = 'push.prompt';
  static const allowIdentifier = 'push.allow';
  static const laterIdentifier = 'push.later';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PushCubit>().state;
    if (!state.showsPrompt) return const SizedBox.shrink();

    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final spacing = context.appSpacing;
    final cubit = context.read<PushCubit>();
    final blocked = state.status == PushStatus.blocked;
    final waiting = state.status == PushStatus.requesting;

    Widget action(String identifier, Widget button) => MergeSemantics(
      child: Semantics(identifier: identifier, child: button),
    );

    return Semantics(
      container: true,
      identifier: identifier,
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.pushPromptTitle, style: textTheme.titleMedium),
              SizedBox(height: spacing.xs),
              RondaSwap(
                layoutBuilder: _topStart,
                child: Column(
                  key: ValueKey(blocked),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (blocked)
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          l10n.pushPromptBlocked,
                          style: textTheme.bodyMedium,
                        ),
                      )
                    else
                      for (final line in [
                        l10n.pushPromptWeekly,
                        l10n.pushPromptChanges,
                        l10n.pushPromptNever,
                      ])
                        Text(line, style: textTheme.bodyMedium),
                    SizedBox(height: spacing.sm),
                    OverflowBar(
                      alignment: MainAxisAlignment.end,
                      spacing: spacing.xs,
                      overflowSpacing: spacing.xs,
                      overflowAlignment: OverflowBarAlignment.end,
                      children: [
                        action(
                          laterIdentifier,
                          TextButton(
                            onPressed: waiting ? null : cubit.dismissed,
                            child: Text(
                              blocked
                                  ? l10n.pushPromptGotIt
                                  : l10n.pushPromptLater,
                            ),
                          ),
                        ),
                        if (!blocked)
                          action(
                            allowIdentifier,
                            FilledButton(
                              onPressed: waiting
                                  ? null
                                  : RondaHaptics.onCommit(cubit.allowTapped),
                              child: Text(l10n.pushPromptAllow),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Both states line up under the title while they swap.
  static Widget _topStart(Widget? current, List<Widget> previous) =>
      Stack(children: [...previous, ?current]);
}
