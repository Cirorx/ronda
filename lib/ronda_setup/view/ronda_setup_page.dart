import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:ronda/attendance/view/attendance_page.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/my_ronda/widgets/this_week_labels.dart';
import 'package:ronda/onboarding/widgets/onboarding_labels.dart';
import 'package:ronda/ronda_setup/cubit/ronda_setup_cubit.dart';
import 'package:ronda/ronda_setup/widgets/ronda_setup_sheet.dart';
import 'package:ronda_repository/ronda_repository.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// "Lugar, hora y anfitriones": every ronda's public place, hour and hosts,
/// set by the admin (`docs/PRODUCT.md` § The weekly loop). Approval leaves
/// all three empty, and nothing invents them. Each ronda also opens its
/// latest "¿Quién vino?", which the admin records when no host can.
class const RondaSetupPage({super.key}) extends StatelessWidget {
  /// Under the admin screen, so the router lets a profile-less owner in.
  static const path = '/admin/rondas';

  /// The route's segment under `/admin`.
  static const segment = 'rondas';

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final cubit = RondaSetupCubit(
          rondaRepository: context.read<RondaRepository>(),
        );
        unawaited(cubit.load());
        return cubit;
      },
      child: const RondaSetupView(),
    );
  }
}

/// The rondas, each with "Cambiar", or why they can't be shown.
class const RondaSetupView({super.key}) extends StatelessWidget {
  /// Maestro's handle on a ronda's "Cambiar".
  static String changeIdentifier(String rondaId) => 'setup.$rondaId';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<RondaSetupCubit>().state;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.setupTitle)),
      body: SafeArea(
        child: switch (state.status) {
          RondaSetupStatus.loading => const Center(
            child: CircularProgressIndicator(),
          ),
          RondaSetupStatus.forbidden => _Message(l10n.adminForbidden),
          RondaSetupStatus.failure => _Message(
            l10n.setupLoadError,
            action: OutlinedButton(
              onPressed: context.read<RondaSetupCubit>().load,
              child: Text(l10n.adminRetry),
            ),
          ),
          RondaSetupStatus.ready => _Rondas(state.rondas),
        },
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

class const _Rondas(final List<RondaSetup> rondas) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.appSpacing;
    return ListView(
      padding: EdgeInsetsDirectional.all(spacing.md),
      children: [
        Text(l10n.setupBody, style: Theme.of(context).textTheme.bodyMedium),
        SizedBox(height: spacing.md),
        if (rondas.isEmpty)
          Text(l10n.setupEmpty, style: Theme.of(context).textTheme.bodyLarge),
        for (final ronda in rondas) ...[
          _RondaCard(ronda),
          SizedBox(height: spacing.sm),
        ],
      ],
    );
  }
}

class const _RondaCard(final RondaSetup ronda) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final spacing = context.appSpacing;
    final barrio = Barrio.fromId(ronda.barrioId);
    String name(String? uid) =>
        [
          for (final member in ronda.members)
            if (member.uid == uid) member.firstName,
        ].firstOrNull ??
        l10n.setupNobody;

    return Card(
      child: Padding(
        padding: EdgeInsetsDirectional.all(spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: spacing.xxs,
          children: [
            Text(
              l10n.rondaLineOf(
                slotDayId: ronda.slotDayId,
                slotBandId: ronda.slotBandId,
                pretextId: ronda.pretextId,
                hour: ronda.hour,
              ),
              style: textTheme.titleMedium,
            ),
            Text(
              barrio == null ? ronda.barrioId : l10n.barrio(barrio),
              style: textTheme.bodyMedium,
            ),
            Text(switch ((ronda.placeName, ronda.placeLandmark)) {
              (null, _) when ronda.hour == null => l10n.thisWeekToConfirmBoth,
              (null, _) => l10n.thisWeekToConfirmPlace,
              (final place?, final landmark?) => l10n.thisWeekPlaceLandmark(
                place,
                landmark,
              ),
              (final place?, null) => place,
            }, style: textTheme.bodyLarge),
            Text(
              l10n.setupHosts(name(ronda.anfitrionUid), name(ronda.colaUid)),
              style: textTheme.bodyMedium,
            ),
            SizedBox(height: spacing.xs),
            MergeSemantics(
              child: Semantics(
                identifier: RondaSetupView.changeIdentifier(ronda.rondaId),
                child: OutlinedButton(
                  onPressed: () => RondaSetupSheet.show(context, ronda),
                  child: Text(l10n.setupChange),
                ),
              ),
            ),
            if (ronda.roll case final roll?)
              TextButton(
                onPressed: () => context.push(
                  AttendancePage.location(
                    ronda.rondaId,
                    roll.week,
                    admin: true,
                  ),
                ),
                child: Text(
                  '${l10n.setupRoll(l10n.shortDate(roll.date))} · '
                  '${l10n.rollMarked(roll.marked, roll.people)}',
                ),
              ),
          ],
        ),
      ),
    );
  }
}
