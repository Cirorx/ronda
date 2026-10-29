import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:push_repository/push_repository.dart';
import 'package:ronda/app/app.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/my_ronda/cubit/this_week_cubit.dart';
import 'package:ronda/my_ronda/widgets/esta_no_sheet.dart';
import 'package:ronda/my_ronda/widgets/this_week_card.dart';
import 'package:ronda/push/push.dart';
import 'package:ronda_repository/ronda_repository.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// The Mi ronda tab: the notifications ask on top while it's pending, then
/// this week's card, or "Estamos armando tu grupo" before a group exists.
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
    final uid = context.read<AppBloc>().state.user.id;
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) {
            final cubit = PushCubit(
              uid: uid,
              pushRepository: context.read<PushRepository>(),
            );
            unawaited(cubit.started());
            return cubit;
          },
        ),
        BlocProvider(
          create: (context) => ThisWeekCubit(
            uid: uid,
            rondaRepository: context.read<RondaRepository>(),
          )..subscribe(),
        ),
      ],
      child: MyRondaView(uid: uid),
    );
  }
}

/// Mi ronda's content, under [MyRondaPage.identifier].
class const MyRondaView({required final String uid, super.key})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.appSpacing;
    final textTheme = Theme.of(context).textTheme;
    final state = context.watch<ThisWeekCubit>().state;

    Widget line(String text) =>
        Text(text, textAlign: TextAlign.center, style: textTheme.bodyLarge);

    return BlocListener<ThisWeekCubit, ThisWeekState>(
      listenWhen: (previous, current) =>
          !previous.estaNoSheet && current.estaNoSheet,
      listener: (context, _) async {
        final cubit = context.read<ThisWeekCubit>();
        await EstaNoSheet(
          onStay: () {},
          onPause: cubit.pauseTapped,
          onMistake: cubit.yesTapped,
        ).show(context);
        cubit.sheetClosed();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.myRondaTabLabel)),
        body: Semantics(
          container: true,
          identifier: MyRondaPage.identifier,
          child: ListView(
            padding: EdgeInsets.all(spacing.md),
            children: [
              const PushPrompt(),
              SizedBox(height: spacing.lg),
              switch (state.status) {
                ThisWeekStatus.loading => const Center(
                  child: CircularProgressIndicator(),
                ),
                ThisWeekStatus.noGroup => line(l10n.myRondaPlaceholder),
                ThisWeekStatus.failure => Column(
                  spacing: spacing.sm,
                  children: [
                    line(l10n.thisWeekLoadError),
                    OutlinedButton(
                      onPressed: context.read<ThisWeekCubit>().subscribe,
                      child: Text(l10n.thisWeekRetry),
                    ),
                  ],
                ),
                ThisWeekStatus.ready => ThisWeekCard(state: state, uid: uid),
              },
            ],
          ),
        ),
      ),
    );
  }
}
