import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:push_repository/push_repository.dart';
import 'package:ronda/app/app.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/push/push.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// The Mi ronda tab: the notifications ask on top while it's pending, and a
/// placeholder until this week's card exists.
///
/// It is where everyone with a profile lands, right after onboarding saves,
/// so the [PushCubit] it provides also keeps this phone's token saved.
class const MyRondaPage({super.key}) extends StatelessWidget {
  static const path = '/ronda';

  /// Maestro's handle on the tab's content, where a flow checks that it
  /// reached Mi ronda. It wraps the whole body, so it outlives whatever the
  /// body shows.
  static const identifier = 'myRonda';

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final cubit = PushCubit(
          uid: context.read<AppBloc>().state.user.id,
          pushRepository: context.read<PushRepository>(),
        );
        unawaited(cubit.started());
        return cubit;
      },
      child: const MyRondaView(),
    );
  }
}

/// Mi ronda's content, under [MyRondaPage.identifier].
class const MyRondaView({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.appSpacing;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.myRondaTabLabel)),
      body: Semantics(
        container: true,
        identifier: MyRondaPage.identifier,
        child: ListView(
          padding: EdgeInsets.all(spacing.md),
          children: [
            const PushPrompt(),
            SizedBox(height: spacing.lg),
            Text(
              l10n.myRondaPlaceholder,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
