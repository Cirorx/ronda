import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/small_plan/cubit/shared_plans_cubit.dart';
import 'package:small_plan_repository/small_plan_repository.dart';

/// The words of Algo chico esta semana, from a plan or what came of it.
///
/// A suggestion has no sentence of its own: it is worded here from its kind
/// and its place, in the phone's language. A plan the member said keeps
/// their words ([SmallPlan.activity]).
extension SmallPlanLabels on AppLocalizations {
  static const _dayIds = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

  /// The weekday's id, as [weekdayName] reads it.
  static String dayId(DateTime at) => _dayIds[at.weekday - 1];

  /// "19:00".
  static String clock(DateTime at) =>
      '${at.hour.toString().padLeft(2, '0')}:'
      '${at.minute.toString().padLeft(2, '0')}';

  /// "el martes a las 19:00".
  String planWhen(DateTime at) =>
      smallPlanWhen(weekdayName(dayId(at)), clock(at));

  /// What the plan is, with no day: the member's own words, or the kind's
  /// sentence with its place. Also the calendar event's title.
  String planWhat(SmallPlan plan) {
    final place = plan.place;
    return switch (plan.kind) {
      _ when plan.activity != null => plan.activity!,
      SmallPlanKind.walk when place != null => smallPlanWhatWalk(place),
      SmallPlanKind.walk => smallPlanWhatWalkNearHome,
      SmallPlanKind.feria when place != null => smallPlanWhatFeria(place),
      SmallPlanKind.feria => smallPlanWhatFeriaAny,
      SmallPlanKind.library when place != null => smallPlanWhatLibrary(place),
      SmallPlanKind.library => smallPlanWhatLibraryAny,
      SmallPlanKind.call => smallPlanWhatCall,
      SmallPlanKind.noPhone => smallPlanWhatNoPhone,
      SmallPlanKind.other => smallPlanWhatWalkNearHome,
    };
  }

  /// "Caminar 30 minutos por la rambla, el martes a las 19:00, desde la
  /// parada 23." The place a member said follows the day; a suggestion's
  /// place is already in what it says.
  String planLine(SmallPlan plan) =>
      smallPlanLine(planWhat(plan), planWhen(plan.at), switch (plan.place) {
        final place? when plan.activity != null => ', $place',
        _ => '',
      });

  /// "Ana propone: Caminar 30 minutos por la rambla, el martes a las 19:00."
  String sharedLine(SharedPlanLine line) => sharedPlanLine(
    line.firstName,
    planLine(
      SmallPlan(
        kind: line.kind,
        at: line.at,
        place: line.place,
        activity: line.activity,
      ),
    ),
  );

  /// Why a plan was held back from the ronda, in plain words, and that it
  /// stays private.
  String heldReason(ShareHoldReason reason) {
    final why = switch (reason) {
      ShareHoldReason.past => sharedPlanHeldPast,
      ShareHoldReason.time => sharedPlanHeldTime,
      ShareHoldReason.words => sharedPlanHeldWords,
      ShareHoldReason.money => sharedPlanHeldMoney,
      ShareHoldReason.address => sharedPlanHeldAddress,
      ShareHoldReason.phone => sharedPlanHeldPhone,
      ShareHoldReason.place => sharedPlanHeldPlace,
      ShareHoldReason.other => sharedPlanHeldOther,
    };
    return '$why $sharedPlanHeldPrivate';
  }

  /// What went wrong on the last tap of ¿Alguien se suma?.
  String sharedProblem(SharedPlansProblem problem) => switch (problem) {
    SharedPlansProblem.shareFailed => sharedPlanShareFailed,
    SharedPlansProblem.joinFailed => sharedPlanJoinFailed,
    SharedPlansProblem.planGone => sharedPlanGone,
  };

  /// "¿Saliste a caminar el martes?": last week's question, by kind.
  String followUp(SmallPlan plan) {
    final day = weekdayName(dayId(plan.at));
    return switch (plan.kind) {
      SmallPlanKind.walk => smallPlanFollowUpWalk(day),
      SmallPlanKind.feria => smallPlanFollowUpFeria(day),
      SmallPlanKind.library => smallPlanFollowUpLibrary(day),
      SmallPlanKind.call => smallPlanFollowUpCall(day),
      SmallPlanKind.noPhone => smallPlanFollowUpNoPhone(day),
      SmallPlanKind.other => smallPlanFollowUpOther(day),
    };
  }

  /// What the forecast says of an outdoor plan's day, when it says.
  String? forecastNote({required bool outdoor, bool? dry}) =>
      switch ((outdoor, dry)) {
        (true, true) => smallPlanDryYes,
        (true, false) => smallPlanDryNo,
        _ => null,
      };

  /// Why the sheet is on "Decilo vos" again.
  String? sayProblem({
    PlanDropReason? dropped,
    SmallPlanFailureKind? failure,
  }) => switch ((dropped, failure)) {
    (PlanDropReason.unclear, _) => smallPlanNotUnderstood,
    (_?, _) => smallPlanDropped,
    (_, SmallPlanFailureKind.notUnderstood) => smallPlanNotUnderstood,
    (_, SmallPlanFailureKind.noMicrophone) => smallPlanNoMicrophone,
    (_, SmallPlanFailureKind.microphoneDenied) => smallPlanMicrophoneDenied,
    (_, _?) => smallPlanReadFailed,
    _ => null,
  };
}
