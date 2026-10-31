part of 'small_plan_cubit.dart';

/// Whether the phone's plan could be read.
enum SmallPlanStatus { loading, ready, failure }

/// What came of the last tap on "Agregar al calendario".
enum SmallPlanCalendar {
  /// Not asked yet.
  idle,

  /// The phone's calendar opened with the plan.
  opened,

  /// A browser downloaded the plan as an `.ics` file.
  downloaded,

  /// Neither could be done.
  failed,
}

final class const SmallPlanState({
  final SmallPlanStatus status = SmallPlanStatus.loading,

  /// What Mi ronda shows: the offer, this week's plan, last week's question.
  final SmallPlanCard card = const SmallPlanNothing(),

  /// What the last tap on the calendar did.
  final SmallPlanCalendar calendar = SmallPlanCalendar.idle,

  /// The follow-up was just answered: the plain reply shows.
  final bool replied = false,

  /// The new plan couldn't be kept on the phone.
  final bool saveFailed = false,
}) extends Equatable {
  /// A copy with the given fields changed.
  SmallPlanState copyWith({
    SmallPlanStatus? status,
    SmallPlanCard? card,
    SmallPlanCalendar? calendar,
    bool? replied,
    bool? saveFailed,
  }) => SmallPlanState(
    status: status ?? this.status,
    card: card ?? this.card,
    calendar: calendar ?? this.calendar,
    replied: replied ?? this.replied,
    saveFailed: saveFailed ?? this.saveFailed,
  );

  @override
  List<Object?> get props => [status, card, calendar, replied, saveFailed];
}
