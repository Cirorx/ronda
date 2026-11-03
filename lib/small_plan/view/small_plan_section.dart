import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/small_plan/cubit/shared_plans_cubit.dart';
import 'package:ronda/small_plan/cubit/small_plan_cubit.dart';
import 'package:ronda/small_plan/view/share_plan_toggle.dart';
import 'package:ronda/small_plan/view/small_plan_sheet.dart';
import 'package:ronda/small_plan/widgets/small_plan_labels.dart';
import 'package:ronda_ui/ronda_ui.dart';
import 'package:small_plan_repository/small_plan_repository.dart';

/// Algo chico esta semana on Mi ronda, under the week's card: "¿Querés
/// proponerte algo chico para esta semana?" once a week, then the plan with
/// "Agregar al calendario" and "Cambiar", and the next week the question
/// "¿Saliste a caminar el martes?" asked once, with the same plain reply to
/// either answer.
///
/// A plan can be opened to the ronda from its card ([SharePlanToggle]), and
/// changing it takes what was opened back.
///
/// It reads the [SmallPlanCubit] that Mi ronda's page provides, and the
/// [SharedPlansCubit] of the week's ronda. Reading the
/// phone shows nothing at all, so the card never flashes in and out.
///
/// A member still [waiting] for a group gets the same card with its own
/// title ("Mientras armamos tu grupo…"): there is no ronda to open a plan
/// to, so no [SharedPlansCubit] is read and the plan has no share switch.
class const SmallPlanSection({
  required final String uid,
  final bool waiting = false,
  super.key,
}) extends StatelessWidget {
  /// Maestro's handles.
  static const chooseIdentifier = 'smallPlan.choose';
  static const notThisWeekIdentifier = 'smallPlan.notThisWeek';
  static const calendarIdentifier = 'smallPlan.calendar';
  static const changeIdentifier = 'smallPlan.change';
  static const yesIdentifier = 'smallPlan.yes';
  static const noIdentifier = 'smallPlan.no';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SmallPlanCubit>().state;
    final cubit = context.read<SmallPlanCubit>();
    final l10n = context.l10n;
    final spacing = context.appSpacing;

    return RondaSwap(
      layoutBuilder: RondaSwap.topStartLayout,
      child: switch (state.status) {
        SmallPlanStatus.loading => const SizedBox.shrink(key: ValueKey('load')),
        SmallPlanStatus.failure => Padding(
          key: const ValueKey('failure'),
          padding: EdgeInsets.only(top: spacing.md),
          child: NoteBanner(
            variant: NoteBannerVariant.warning,
            message: l10n.smallPlanLoadError,
          ),
        ),
        SmallPlanStatus.ready => switch (state.card) {
          SmallPlanNothing() => const SizedBox.shrink(key: ValueKey('none')),
          final card => Padding(
            key: ValueKey(card.runtimeType),
            padding: EdgeInsets.only(top: spacing.md),
            child: _Card(
              uid: uid,
              waiting: waiting,
              card: card,
              state: state,
              onChoose: () => _choose(context, cubit),
            ),
          ),
        },
      },
    );
  }

  Future<void> _choose(BuildContext context, SmallPlanCubit cubit) async {
    final shared = waiting ? null : context.read<SharedPlansCubit>();
    final plan = await SmallPlanSheet.show(context, uid: uid);
    if (plan == null) return;
    // What was opened to the ronda was the old plan: it is taken back.
    if (shared != null) unawaited(shared.planChanged());
    await cubit.planChosen(plan);
  }
}

class const _Card({
  required final String uid,
  required final bool waiting,
  required final SmallPlanCard card,
  required final SmallPlanState state,
  required final VoidCallback onChoose,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.appSpacing;
    final textTheme = Theme.of(context).textTheme;
    final cubit = context.read<SmallPlanCubit>();

    Widget action(String identifier, Widget button) => MergeSemantics(
      child: Semantics(identifier: identifier, child: button),
    );
    Widget title(String text) =>
        Semantics(header: true, child: Text(text, style: textTheme.titleSmall));

    final children = switch (card) {
      SmallPlanOffer() => [
        if (state.replied)
          Semantics(
            liveRegion: true,
            child: Text(
              l10n.smallPlanFollowUpReply,
              style: textTheme.bodyMedium,
            ),
          ),
        title(
          waiting ? l10n.smallPlanOfferWaitingTitle : l10n.smallPlanOfferTitle,
        ),
        Text(l10n.smallPlanOfferBody, style: textTheme.bodyMedium),
        Wrap(
          spacing: spacing.sm,
          runSpacing: spacing.xs,
          children: [
            action(
              SmallPlanSection.chooseIdentifier,
              FilledButton(
                onPressed: onChoose,
                child: Text(l10n.smallPlanOfferChoose),
              ),
            ),
            action(
              SmallPlanSection.notThisWeekIdentifier,
              TextButton(
                onPressed: cubit.notThisWeek,
                child: Text(l10n.smallPlanOfferNotThisWeek),
              ),
            ),
          ],
        ),
      ],
      SmallPlanSet(:final plan) => [
        title(l10n.smallPlanSetTitle),
        Text(l10n.planLine(plan), style: textTheme.bodyLarge),
        Wrap(
          spacing: spacing.sm,
          runSpacing: spacing.xs,
          children: [
            action(
              SmallPlanSection.calendarIdentifier,
              FilledButton.icon(
                onPressed: () =>
                    unawaited(cubit.calendarTapped(l10n.planWhat(plan))),
                icon: const Icon(Icons.event_outlined),
                label: Text(l10n.smallPlanAddToCalendar),
              ),
            ),
            action(
              SmallPlanSection.changeIdentifier,
              OutlinedButton(
                onPressed: onChoose,
                child: Text(l10n.smallPlanChange),
              ),
            ),
          ],
        ),
        if (!waiting) SharePlanToggle(plan: plan),
        if (switch (state.calendar) {
              SmallPlanCalendar.idle => null,
              SmallPlanCalendar.opened => l10n.smallPlanCalendarOpened,
              SmallPlanCalendar.downloaded => l10n.smallPlanCalendarDownloaded,
              SmallPlanCalendar.failed => l10n.smallPlanCalendarFailed,
            }
            case final text?)
          Semantics(
            liveRegion: true,
            child: Text(text, style: textTheme.bodyMedium),
          ),
      ],
      SmallPlanFollowUp(:final plan) => [
        title(l10n.followUp(plan)),
        Wrap(
          spacing: spacing.sm,
          runSpacing: spacing.xs,
          children: [
            action(
              SmallPlanSection.yesIdentifier,
              FilledButton(
                onPressed: cubit.followUpAnswered,
                child: Text(l10n.smallPlanFollowUpYes),
              ),
            ),
            action(
              SmallPlanSection.noIdentifier,
              OutlinedButton(
                onPressed: cubit.followUpAnswered,
                child: Text(l10n.smallPlanFollowUpNo),
              ),
            ),
          ],
        ),
      ],
      SmallPlanNothing() => const <Widget>[],
    };

    return Card(
      child: Padding(
        padding: EdgeInsetsDirectional.all(spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: spacing.sm,
          children: [
            ...children,
            if (state.saveFailed)
              NoteBanner(
                variant: NoteBannerVariant.warning,
                message: l10n.smallPlanSaveError,
              ),
          ],
        ),
      ),
    );
  }
}
