import 'package:equatable/equatable.dart';
import 'package:small_plan_repository/src/models/small_plan.dart';

/// Why a plan was dropped: what the member said was about
/// (see `functions/small_plans.py`).
enum PlanDropReason {
  /// A health or medical goal.
  health,

  /// A diet or weight.
  diet,

  /// Money.
  money,

  /// Another person.
  people,

  /// Nothing usable.
  unclear;

  /// The reason the server named; [unclear] for any other.
  static PlanDropReason fromName(String name) =>
      PlanDropReason.values.asNameMap()[name] ?? unclear;
}

/// What came of what a member said or typed.
sealed class SmallPlanReading extends Equatable {
  /// A reading.
  const new();
}

/// {@template small_plan_read}
/// It became a [plan]. [moved] when the day isn't the one they named
/// because it rains; [dry] is what the forecast says of the day (`null`
/// when it has no word).
/// {@endtemplate}
final class const SmallPlanRead({
  required final SmallPlan plan,
  final bool moved = false,
  final bool? dry,
}) extends SmallPlanReading {
  /// {@macro small_plan_read}
  this;

  @override
  List<Object?> get props => [plan, moved, dry];
}

/// {@template small_plan_dropped}
/// It was dropped, for [reason].
/// {@endtemplate}
final class const SmallPlanDropped(final PlanDropReason reason)
    extends SmallPlanReading {
  /// {@macro small_plan_dropped}
  this;

  @override
  List<Object?> get props => [reason];
}
