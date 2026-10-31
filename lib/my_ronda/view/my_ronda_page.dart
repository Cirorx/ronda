import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:push_repository/push_repository.dart';
import 'package:ronda/acta/acta.dart';
import 'package:ronda/app/app.dart';
import 'package:ronda/buddy/buddy.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/my_ronda/cubit/bench_offer_cubit.dart';
import 'package:ronda/my_ronda/cubit/seguimos_cubit.dart';
import 'package:ronda/my_ronda/cubit/this_week_cubit.dart';
import 'package:ronda/my_ronda/cubit/waiting_cubit.dart';
import 'package:ronda/my_ronda/widgets/bench_offer_card.dart';
import 'package:ronda/my_ronda/widgets/esta_no_sheet.dart';
import 'package:ronda/my_ronda/widgets/seguimos_card.dart';
import 'package:ronda/my_ronda/widgets/this_week_card.dart';
import 'package:ronda/my_ronda/widgets/waiting_card.dart';
import 'package:ronda/my_ronda/widgets/who_is_going.dart';
import 'package:ronda/push/push.dart';
import 'package:ronda_repository/ronda_repository.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// The Mi ronda tab: the notifications ask on top while it's pending, then
/// an offer of a freed seat from a bench while one matters, the ¿seguimos?
/// card while there is one, then this week's card and the buddy, or
/// "Todavía no tenés grupo" with the waiting list's card before a group
/// exists. A member who left at the ¿seguimos? close sees only that card
/// ("Gracias por venir."). While it reads it says so; each state swaps in
/// for the last on a [RondaSwap].
///
/// Wider than a phone it keeps to a readable column; on a desktop window
/// the week's card stays in it and "Quiénes van" (with what each brings
/// drawn), the buddy and the acta's link stand beside it ([PaperColumns]).
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
        BlocProvider(
          create: (context) => SeguimosCubit(
            uid: uid,
            rondaRepository: context.read<RondaRepository>(),
          )..subscribe(),
        ),
        BlocProvider(
          create: (context) => BenchOfferCubit(
            uid: uid,
            rondaRepository: context.read<RondaRepository>(),
          )..subscribe(),
        ),
        BlocProvider(
          create: (context) => WaitingCubit(
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

    final wide = context.windowSize == WindowSize.expanded;
    // The week shown beside the card on a desktop window.
    final week = switch (state.week) {
      final week? when !week.hasLeft && state.status == ThisWeekStatus.ready =>
        week,
      _ => null,
    };
    final main = <Widget>[
      const PushPrompt(),
      SizedBox(height: spacing.lg),
      const BenchOfferCard(),
      const SeguimosCard(),
      RondaSwap(
        layoutBuilder: RondaSwap.topStartLayout,
        child: KeyedSubtree(
          key: ValueKey((state.status, state.week?.hasLeft ?? false)),
          child: switch (state.status) {
            ThisWeekStatus.loading => LoadingStatus(l10n.myRondaLoading),
            ThisWeekStatus.noGroup => Column(
              spacing: spacing.xs,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    l10n.myRondaNoGroupTitle,
                    textAlign: TextAlign.center,
                    style: textTheme.titleMedium,
                  ),
                ),
                line(l10n.myRondaNoGroupBody),
                const WaitingCard(),
              ],
            ),
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
            ThisWeekStatus.ready when state.week!.hasLeft =>
              const SizedBox.shrink(),
            ThisWeekStatus.ready => ThisWeekCard(
              state: state,
              uid: uid,
              showWhoIsGoing: !wide,
            ),
          },
        ),
      ),
    ];
    // The ronda's context: on a phone under the card, on a desktop beside it.
    final aside = <Widget>[
      if (state.week case final week? when !week.hasLeft) ...[
        BuddySection(rondaId: week.rondaId, uid: uid),
        ActaLink(rondaId: week.rondaId),
      ],
    ];

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
          child: switch (context.windowSize) {
            WindowSize.compact => ListView(
              padding: EdgeInsets.all(spacing.md),
              children: [...main, ...aside],
            ),
            WindowSize.medium => ReadableColumn(
              child: ListView(
                padding: EdgeInsets.all(spacing.md),
                children: [...main, ...aside],
              ),
            ),
            WindowSize.expanded => PaperColumns(
              main: ListView(
                padding: EdgeInsets.all(spacing.md),
                children: main,
              ),
              side: ListView(
                padding: EdgeInsetsDirectional.symmetric(vertical: spacing.md),
                children: [
                  if (week case final week? when week.week != null)
                    Card(
                      child: Padding(
                        padding: EdgeInsets.all(spacing.md),
                        child: WhoIsGoing(
                          week: week,
                          uid: uid,
                          showObjects: true,
                        ),
                      ),
                    ),
                  ...aside,
                ],
              ),
            ),
          },
        ),
      ),
    );
  }
}
