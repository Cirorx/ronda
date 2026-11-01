import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/small_plan/cubit/shared_plans_cubit.dart';
import 'package:ronda/small_plan/widgets/small_plan_labels.dart';
import 'package:ronda_ui/ronda_ui.dart';
import 'package:small_plan_repository/small_plan_repository.dart';

/// ¿Alguien se suma? on Mi ronda: one line for each plan another member
/// opened to the ronda, "Ana propone: Caminar 30 minutos por la rambla, el
/// martes a las 19:00, desde la parada 23." with [Me sumo]. Once joined the
/// line says "Te sumaste." with "Ya no voy".
///
/// It reads the [SharedPlansCubit] above it. A plan whose time has passed is
/// not shown, and with nothing to show the section is nothing at all: no
/// empty state, no count. Joining sends no notification.
class const SharedPlansSection({super.key}) extends StatelessWidget {
  /// Maestro's handles; the author's uid is appended.
  static const joinIdentifier = 'sharedPlan.join';
  static const leaveIdentifier = 'sharedPlan.leave';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SharedPlansCubit>().state;
    final spacing = context.appSpacing;
    final now = DateTime.now();
    final lines = [
      for (final line in state.plans.lines)
        if (line.at.isAfter(now)) line,
    ];

    return RondaSwap(
      layoutBuilder: RondaSwap.topStartLayout,
      child: lines.isEmpty
          ? const SizedBox.shrink(key: ValueKey('none'))
          : Padding(
              key: const ValueKey('lines'),
              padding: EdgeInsets.only(top: spacing.md),
              child: Column(
                spacing: spacing.sm,
                children: [
                  for (final line in lines)
                    _Line(
                      key: ValueKey(line.authorUid),
                      line: line,
                      busy: state.joining == line.authorUid,
                    ),
                  if (state.problem case final problem?
                      when problem != SharedPlansProblem.shareFailed)
                    NoteBanner(
                      variant: NoteBannerVariant.warning,
                      message: context.l10n.sharedProblem(problem),
                    ),
                ],
              ),
            ),
    );
  }
}

class const _Line({
  required final SharedPlanLine line,
  required final bool busy,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.appSpacing;
    final textTheme = Theme.of(context).textTheme;
    final cubit = context.read<SharedPlansCubit>();
    const join = SharedPlansSection.joinIdentifier;
    const leave = SharedPlansSection.leaveIdentifier;

    return Card(
      child: Padding(
        padding: EdgeInsetsDirectional.all(spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: spacing.sm,
          children: [
            Text(l10n.sharedLine(line), style: textTheme.bodyLarge),
            if (line.joined) ...[
              Semantics(
                liveRegion: true,
                child: Text(l10n.sharedPlanJoined, style: textTheme.bodyMedium),
              ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: MergeSemantics(
                  child: Semantics(
                    identifier: '$leave.${line.authorUid}',
                    child: OutlinedButton(
                      onPressed: busy
                          ? null
                          : () => unawaited(cubit.leaveTapped(line.authorUid)),
                      child: Text(l10n.sharedPlanLeave),
                    ),
                  ),
                ),
              ),
            ] else
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: MergeSemantics(
                  child: Semantics(
                    identifier: '$join.${line.authorUid}',
                    child: FilledButton(
                      onPressed: busy
                          ? null
                          : () => unawaited(cubit.joinTapped(line.authorUid)),
                      child: Text(l10n.sharedPlanJoin),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
