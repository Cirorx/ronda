import 'package:equatable/equatable.dart';
import 'package:small_plan_repository/src/models/small_plan.dart';

/// What Mi ronda shows of Algo chico esta semana.
sealed class SmallPlanCard extends Equatable {
  /// A card.
  const new();
}

/// {@template small_plan_offer}
/// "¿Querés proponerte algo chico para esta semana?": nothing is planned
/// for this week and the member hasn't put it off.
/// {@endtemplate}
final class SmallPlanOffer extends SmallPlanCard {
  /// {@macro small_plan_offer}
  const new();

  @override
  List<Object?> get props => const [];
}

/// {@template small_plan_set}
/// This week's [plan], with the calendar and "Cambiar".
/// {@endtemplate}
final class const SmallPlanSet(final SmallPlan plan) extends SmallPlanCard {
  /// {@macro small_plan_set}
  this;

  @override
  List<Object?> get props => [plan];
}

/// {@template small_plan_follow_up}
/// Last week's [plan], asked about once: "¿Saliste a caminar el martes?".
/// {@endtemplate}
final class const SmallPlanFollowUp(final SmallPlan plan)
    extends SmallPlanCard {
  /// {@macro small_plan_follow_up}
  this;

  @override
  List<Object?> get props => [plan];
}

/// {@template small_plan_nothing}
/// Nothing to show: the member put this week's offer off.
/// {@endtemplate}
final class SmallPlanNothing extends SmallPlanCard {
  /// {@macro small_plan_nothing}
  const new();

  @override
  List<Object?> get props => const [];
}
