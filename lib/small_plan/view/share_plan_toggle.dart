import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/small_plan/cubit/shared_plans_cubit.dart';
import 'package:ronda/small_plan/widgets/small_plan_labels.dart';
import 'package:ronda_ui/ronda_ui.dart';
import 'package:small_plan_repository/small_plan_repository.dart';

/// "Avisarle a la ronda" under the member's plan: a switch that opens the
/// plan to their ronda, so it becomes extra time with the same neighbours in
/// a second place, started by them. Only then does the plan's text leave the
/// phone.
///
/// A plan that a check holds back says why in plain words and stays private.
/// Once someone says "Me sumo" the card names them, by first name; when
/// nobody does it shows nothing, never that nobody came. It reads the
/// [SharedPlansCubit] above it, and shows nothing for a plan with no place to
/// join (a call, an afternoon without the phone) or one whose time passed.
class const SharePlanToggle({required final SmallPlan plan, super.key})
    extends StatelessWidget {
  /// Maestro's handle.
  static const identifier = 'sharedPlan.toggle';

  @override
  Widget build(BuildContext context) {
    if (plan.kind == SmallPlanKind.call ||
        plan.kind == SmallPlanKind.noPhone ||
        !plan.at.isAfter(DateTime.now())) {
      return const SizedBox.shrink();
    }
    final state = context.watch<SharedPlansCubit>().state;
    if (state.status != SharedPlansStatus.ready) return const SizedBox.shrink();
    final l10n = context.l10n;
    final spacing = context.appSpacing;
    final textTheme = Theme.of(context).textTheme;
    final cubit = context.read<SharedPlansCubit>();
    final mine = state.plans.mine;
    final shared = mine != null && mine.at == plan.at;
    final joined = shared ? mine.joined : const <String>[];

    // A switch's callback takes its new value positionally.
    // ignore: avoid_positional_boolean_parameters
    void change(bool on) => unawaited(
      on
          ? cubit.shareTapped(plan, l10n.planWhat(plan))
          : cubit.withdrawTapped(),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: spacing.xs,
      children: [
        MergeSemantics(
          child: Semantics(
            identifier: identifier,
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.sharedPlanToggleTitle),
              subtitle: Text(l10n.sharedPlanToggleBody),
              value: shared,
              onChanged: state.sharing ? null : change,
            ),
          ),
        ),
        if (joined.isNotEmpty)
          Semantics(
            liveRegion: true,
            child: Text(
              l10n.sharedPlanJoiners(joined.join(', ')),
              style: textTheme.bodyMedium,
            ),
          ),
        if (state.held case final held?)
          NoteBanner(
            variant: NoteBannerVariant.warning,
            message: l10n.heldReason(held),
          ),
        if (state.problem == SharedPlansProblem.shareFailed)
          NoteBanner(
            variant: NoteBannerVariant.warning,
            message: l10n.sharedPlanShareFailed,
          ),
      ],
    );
  }
}
