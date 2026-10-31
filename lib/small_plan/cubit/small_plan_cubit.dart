import 'package:bloc/bloc.dart';
import 'package:calendar_client/calendar_client.dart';
import 'package:equatable/equatable.dart';
import 'package:small_plan_repository/small_plan_repository.dart';

part 'small_plan_state.dart';

/// Algo chico esta semana on Mi ronda: the offer once a week, the plan with
/// its calendar, and last week's question asked once.
///
/// The plan lives on the phone only ([SmallPlanRepository]); nothing here
/// reaches the server.
class SmallPlanCubit extends Cubit<SmallPlanState> {
  new({required this._uid, required this._smallPlanRepository})
    : super(const SmallPlanState());

  final String _uid;
  final SmallPlanRepository _smallPlanRepository;

  /// Reads what the phone kept and decides the card.
  Future<void> load() async {
    emit(state.copyWith(status: SmallPlanStatus.loading));
    try {
      final card = await _smallPlanRepository.current(_uid);
      if (isClosed) return;
      emit(state.copyWith(status: SmallPlanStatus.ready, card: card));
    } on SmallPlanFailure catch (failure, stackTrace) {
      addError(failure, stackTrace);
      if (!isClosed) emit(state.copyWith(status: SmallPlanStatus.failure));
    }
  }

  /// A plan was chosen in the sheet: it is kept, and shows.
  Future<void> planChosen(SmallPlan plan) async {
    try {
      await _smallPlanRepository.save(_uid, plan);
    } on SmallPlanFailure catch (failure, stackTrace) {
      addError(failure, stackTrace);
      if (!isClosed) emit(state.copyWith(saveFailed: true));
      return;
    }
    if (isClosed) return;
    emit(
      state.copyWith(
        card: SmallPlanSet(plan),
        calendar: SmallPlanCalendar.idle,
        replied: false,
        saveFailed: false,
      ),
    );
  }

  /// "Agregar al calendario": opens the phone's calendar, or downloads the
  /// `.ics` file on web, with [title] as the event's name.
  Future<void> calendarTapped(String title) async {
    if (state.card case SmallPlanSet(:final plan)) {
      try {
        final outcome = await _smallPlanRepository.addToCalendar(
          plan,
          title: title,
        );
        if (isClosed) return;
        emit(
          state.copyWith(
            calendar: switch (outcome) {
              CalendarOutcome.opened => SmallPlanCalendar.opened,
              CalendarOutcome.downloaded => SmallPlanCalendar.downloaded,
            },
          ),
        );
      } on SmallPlanFailure {
        // The calendar isn't there; the screen says so and nothing is lost.
        if (!isClosed) {
          emit(state.copyWith(calendar: SmallPlanCalendar.failed));
        }
      }
    }
  }

  /// "Sí" or "Esta vez no": the same plain reply, and the plan is forgotten.
  Future<void> followUpAnswered() async {
    try {
      await _smallPlanRepository.answerFollowUp(_uid);
    } on SmallPlanFailure catch (failure, stackTrace) {
      addError(failure, stackTrace);
    }
    if (isClosed) return;
    emit(state.copyWith(card: const SmallPlanOffer(), replied: true));
  }

  /// "Esta semana no": the offer stays away until next week.
  Future<void> notThisWeek() async {
    try {
      await _smallPlanRepository.skipThisWeek(_uid);
    } on SmallPlanFailure catch (failure, stackTrace) {
      addError(failure, stackTrace);
    }
    if (isClosed) return;
    emit(state.copyWith(card: const SmallPlanNothing()));
  }
}
