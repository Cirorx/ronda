import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:push_repository/push_repository.dart';
import 'package:ronda/app/app.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/settings/cubit/notifications_cubit.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// Ajustes → Avisos: whether notifications are on, what Ronda sends, and
/// [Prender los avisos] while the phone can still ask; how to allow them in
/// the phone's settings when it refused for good.
class const NotificationsPage({super.key}) extends StatelessWidget {
  /// The route's segment under `/ajustes`.
  static const segment = 'avisos';
  static const path = '/ajustes/$segment';

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final cubit = NotificationsCubit(
          uid: context.read<AppBloc>().state.user.id,
          pushRepository: context.read<PushRepository>(),
        );
        unawaited(cubit.started());
        return cubit;
      },
      child: const NotificationsView(),
    );
  }
}

/// Avisos' content. It reads the permission again whenever the app comes
/// back to the front, so turning them on in the phone's settings shows.
/// While it reads, it says so; what it finds swaps in and is read out.
/// [Prender los avisos] is felt as it is tapped.
class NotificationsView extends StatefulWidget {
  const new({super.key});

  /// Maestro's handle on [Prender los avisos].
  static const turnOnIdentifier = 'notifications.turnOn';

  @override
  State<NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends State<NotificationsView> {
  late final AppLifecycleListener _lifecycle;

  /// Each state lines up at the top while they swap.
  static Widget _topStart(Widget? current, List<Widget> previous) =>
      Stack(children: [...previous, ?current]);

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () => unawaited(context.read<NotificationsCubit>().started()),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final spacing = context.appSpacing;
    final state = context.watch<NotificationsCubit>().state;

    final headline = switch (state.status) {
      NotificationsStatus.checking => null,
      NotificationsStatus.on => l10n.notificationsOn,
      NotificationsStatus.off ||
      NotificationsStatus.asking ||
      NotificationsStatus.refused => l10n.notificationsOff,
      NotificationsStatus.blocked => l10n.pushPromptBlocked,
      NotificationsStatus.unknown => l10n.notificationsUnknown,
    };
    final explains =
        state.status != NotificationsStatus.blocked &&
        state.status != NotificationsStatus.unknown;

    final refused = state.status == NotificationsStatus.refused;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsNotificationsRow)),
      body: ListView(
        padding: EdgeInsets.all(spacing.md),
        children: [
          RondaSwap(
            layoutBuilder: _topStart,
            child: switch (headline) {
              null => LoadingStatus.inline(
                key: const ValueKey(NotificationsStatus.checking),
                l10n.notificationsChecking,
              ),
              final headline => Column(
                // "Asking" looks like "off" until the phone answers.
                key: ValueKey((headline, refused)),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    liveRegion: true,
                    child: Text(headline, style: textTheme.titleMedium),
                  ),
                  SizedBox(height: spacing.sm),
                  if (explains)
                    for (final line in [
                      l10n.pushPromptWeekly,
                      l10n.pushPromptChanges,
                      l10n.pushPromptNever,
                    ])
                      Text(line, style: textTheme.bodyLarge),
                  if (refused) ...[
                    SizedBox(height: spacing.sm),
                    Text(
                      l10n.notificationsRefusedHint,
                      style: textTheme.bodyLarge,
                    ),
                  ],
                  if (state.canTurnOn) ...[
                    SizedBox(height: spacing.lg),
                    MergeSemantics(
                      child: Semantics(
                        identifier: NotificationsView.turnOnIdentifier,
                        child: FilledButton(
                          onPressed: state.status == NotificationsStatus.asking
                              ? null
                              : RondaHaptics.onCommit(
                                  context
                                      .read<NotificationsCubit>()
                                      .turnOnTapped,
                                ),
                          child: Text(
                            l10n.notificationsTurnOn,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            },
          ),
        ],
      ),
    );
  }
}
